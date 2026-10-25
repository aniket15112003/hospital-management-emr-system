/**
 * Trusted backend operations for the HMS Admin Panel.
 *
 *  - adminCreateUser / adminSetUserRole / adminSetUserStatus
 *      The only way to create accounts or change roles/status. Sets the
 *      `role` custom claim used by Security Rules and writes users/{uid}.
 *  - allocateDocumentNumber
 *      Issues UHID / OPD / receipt ... numbers inside a Firestore
 *      transaction on counters/{docType}. For use by future modules.
 *  - audit* triggers
 *      Append audit_logs entries for master-data and settings changes.
 *
 * The region must match AppConfig.functionsRegion in the Flutter app.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { setGlobalOptions, logger } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

const db = getFirestore();
const auth = getAuth();

const ROLES = [
  "super_admin",
  "admin",
  "receptionist",
  "doctor",
  "lab_user",
  "pharmacy_user",
  "nursing_user",
  "accounts_user",
];
const PRIVILEGED = new Set(["super_admin", "admin"]);
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

// ---------------------------------------------------------------- helpers

/** Loads the caller's profile and permissions; throws if not allowed in. */
async function loadCaller(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = request.auth.uid;
  const role = request.auth.token.role || "";
  const profile = await db.doc(`users/${uid}`).get();
  if (!profile.exists || profile.get("status") !== "active") {
    throw new HttpsError("permission-denied", "Your account is not active.");
  }
  let permissions = {};
  if (role && role !== "super_admin") {
    const r = await db.doc(`roles/${role}`).get();
    permissions = (r.exists && r.get("permissions")) || {};
  }
  return {
    uid,
    role,
    name: profile.get("displayName") || request.auth.token.email || uid,
    can: (module, action) =>
      role === "super_admin" ||
      (Array.isArray(permissions[module]) && permissions[module].includes(action)),
  };
}

/**
 * Mirrors lib/core/auth/user_admin_policy.dart. Returns a denial reason or
 * null when allowed.
 */
function userAdminDenial(caller, action, { targetUid, targetRole, newRole } = {}) {
  const isSuper = caller.role === "super_admin";
  if (!isSuper && !caller.can("users", action)) {
    return `You do not have permission to ${action} users.`;
  }
  if (targetUid && targetUid === caller.uid) {
    return "You cannot change your own account role or status.";
  }
  if (!isSuper && targetRole && PRIVILEGED.has(targetRole)) {
    return "Only a Super Admin can modify privileged accounts.";
  }
  if (!isSuper && newRole && PRIVILEGED.has(newRole)) {
    return "Only a Super Admin can assign privileged roles.";
  }
  return null;
}

async function writeAudit(entry) {
  await db.collection("audit_logs").add({
    timestamp: FieldValue.serverTimestamp(),
    result: "success",
    metadata: {},
    ...entry,
  });
}

function requireString(value, name, max = 200) {
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    throw new HttpsError("invalid-argument", `${name} is required.`);
  }
  return value.trim();
}

function requireRole(value) {
  if (!ROLES.includes(value)) {
    throw new HttpsError("invalid-argument", "Unknown role.");
  }
  return value;
}

async function guard(caller, action, ctx, auditBase) {
  const denied = userAdminDenial(caller, action, ctx);
  if (denied) {
    await writeAudit({ ...auditBase, result: "denied", metadata: { reason: denied } });
    throw new HttpsError("permission-denied", denied);
  }
}

// ------------------------------------------------------- user management

exports.adminCreateUser = onCall(async (request) => {
  const caller = await loadCaller(request);
  const data = request.data || {};
  const displayName = requireString(data.displayName, "Display name", 120);
  const email = requireString(data.email, "Email", 200).toLowerCase();
  if (!EMAIL_RE.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }
  const role = requireRole(data.role);
  const phone = typeof data.phone === "string" && data.phone.trim() ? data.phone.trim() : null;

  const auditBase = {
    actorUid: caller.uid,
    actorName: caller.name,
    action: "create_user",
    module: "users",
    collection: "users",
    recordLabel: email,
  };
  await guard(caller, "create", { newRole: role }, auditBase);

  let user;
  try {
    // No password is set here; the user chooses one via the setup link.
    user = await auth.createUser({ email, displayName, disabled: false });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "A user with this email already exists.");
    }
    logger.error("createUser failed", e);
    throw new HttpsError("internal", "Could not create the account.");
  }

  try {
    await auth.setCustomUserClaims(user.uid, { role });
    await db.doc(`users/${user.uid}`).set({
      displayName,
      email,
      phone,
      role,
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: caller.uid,
      updatedBy: caller.uid,
    });
  } catch (e) {
    // Roll back the Auth account so no half-provisioned user remains.
    await auth.deleteUser(user.uid).catch(() => {});
    logger.error("provisioning failed", e);
    throw new HttpsError("internal", "Could not provision the account.");
  }

  let passwordSetupLink = null;
  try {
    passwordSetupLink = await auth.generatePasswordResetLink(email);
  } catch (e) {
    logger.warn("Could not generate password link", e);
  }

  await writeAudit({ ...auditBase, recordId: user.uid, metadata: { role } });
  return { uid: user.uid, passwordSetupLink };
});

exports.adminSetUserRole = onCall(async (request) => {
  const caller = await loadCaller(request);
  const uid = requireString(request.data?.uid, "User", 128);
  const role = requireRole(request.data?.role);
  const ref = db.doc(`users/${uid}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "User not found.");
  const from = snap.get("role");

  const auditBase = {
    actorUid: caller.uid,
    actorName: caller.name,
    action: "change_role",
    module: "users",
    collection: "users",
    recordId: uid,
    recordLabel: snap.get("email"),
  };
  await guard(caller, "edit", { targetUid: uid, targetRole: from, newRole: role }, auditBase);

  await auth.setCustomUserClaims(uid, { role });
  await ref.update({ role, updatedAt: FieldValue.serverTimestamp(), updatedBy: caller.uid });
  await writeAudit({ ...auditBase, metadata: { from, to: role } });
  return { ok: true };
});

exports.adminSetUserStatus = onCall(async (request) => {
  const caller = await loadCaller(request);
  const uid = requireString(request.data?.uid, "User", 128);
  const status = request.data?.status;
  if (!["active", "inactive"].includes(status)) {
    throw new HttpsError("invalid-argument", "Status must be active or inactive.");
  }
  const ref = db.doc(`users/${uid}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "User not found.");

  const auditBase = {
    actorUid: caller.uid,
    actorName: caller.name,
    action: status === "active" ? "activate_user" : "deactivate_user",
    module: "users",
    collection: "users",
    recordId: uid,
    recordLabel: snap.get("email"),
  };
  await guard(caller, "deactivate", { targetUid: uid, targetRole: snap.get("role") }, auditBase);

  await auth.updateUser(uid, { disabled: status !== "active" });
  if (status !== "active") await auth.revokeRefreshTokens(uid);
  await ref.update({ status, updatedAt: FieldValue.serverTimestamp(), updatedBy: caller.uid });
  await writeAudit(auditBase);
  return { ok: true };
});

// ---------------------------------------------------- document numbering

const NUMBERED_DOC_TYPES = new Set([
  "uhid",
  "opd_encounter",
  "receipt",
  "invoice",
  "ipd_admission",
  "lab_order",
  "pharmacy_bill",
]);

/** Date parts in the hospital's time zone. */
function dateParts(date, timeZone) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    })
      .formatToParts(date)
      .map((p) => [p.type, p.value]),
  );
  return { yyyy: parts.year, mm: parts.month, dd: parts.day };
}

/** Mirrors lib/core/utils/numbering.dart formatDocumentNumber. */
function formatNumber(cfg, seq, d) {
  const segment = {
    YYYY: d.yyyy,
    YYMM: d.yyyy.slice(2) + d.mm,
    YYYYMM: d.yyyy + d.mm,
    YYYYMMDD: d.yyyy + d.mm + d.dd,
  }[cfg.dateSegment] || "";
  const sequence = String(seq).padStart(cfg.padding, "0");
  return [cfg.prefix, segment, sequence].filter(Boolean).join(cfg.separator);
}

function periodKey(resetPolicy, d) {
  switch (resetPolicy) {
    case "yearly": return d.yyyy;
    case "monthly": return `${d.yyyy}-${d.mm}`;
    case "daily": return `${d.yyyy}-${d.mm}-${d.dd}`;
    default: return "all";
  }
}

exports.allocateDocumentNumber = onCall(async (request) => {
  await loadCaller(request);
  const docType = request.data?.docType;
  if (!NUMBERED_DOC_TYPES.has(docType)) {
    throw new HttpsError("invalid-argument", "Unknown document type.");
  }
  const system = await db.doc("system_settings/general").get();
  const timeZone = (system.exists && system.get("timezone")) || "Asia/Kolkata";

  return db.runTransaction(async (tx) => {
    const cfgSnap = await tx.get(db.doc(`numbering_settings/${docType}`));
    if (!cfgSnap.exists) {
      throw new HttpsError("failed-precondition", `Numbering for ${docType} is not configured.`);
    }
    const c = cfgSnap.data();
    const cfg = {
      prefix: c.prefix,
      separator: c.separator ?? "-",
      dateSegment: c.dateSegment || "none",
      padding: Number(c.padding) || 6,
      resetPolicy: c.resetPolicy || "never",
      startAt: Number(c.startAt) || 1,
    };
    const counterRef = db.doc(`counters/${docType}`);
    const counter = await tx.get(counterRef);
    const d = dateParts(new Date(), timeZone);
    const period = periodKey(cfg.resetPolicy, d);
    const sameperiod = counter.exists && counter.get("period") === period;
    const sequence = sameperiod ? counter.get("value") + 1 : cfg.startAt;
    tx.set(counterRef, { value: sequence, period, updatedAt: FieldValue.serverTimestamp() });
    return { number: formatNumber(cfg, sequence, d), sequence };
  });
});

// --------------------------------------------------------- audit triggers

/** Collections audited automatically, with their permission module. */
const AUDITED = {
  departments: "departments",
  doctors: "doctors",
  opd_charges: "opd_charges",
  lab_tests: "lab_tests",
  medicines: "medicines",
  wards: "wards_rooms_beds",
  rooms: "wards_rooms_beds",
  beds: "wards_rooms_beds",
  billing_masters: "billing_masters",
  prescription_templates: "prescription_templates",
  roles: "roles",
  hospital_settings: "hospital_profile",
  numbering_settings: "numbering",
  print_settings: "print_settings",
  system_settings: "system_settings",
};

const IGNORED_FIELDS = new Set(["updatedAt", "updatedBy"]);

function changedFields(before, after) {
  const keys = new Set([...Object.keys(before || {}), ...Object.keys(after || {})]);
  return [...keys].filter(
    (k) => !IGNORED_FIELDS.has(k) && JSON.stringify(before?.[k]) !== JSON.stringify(after?.[k]),
  );
}

function recordLabel(data, id) {
  return data?.name || data?.fullName || data?.roomNumber || data?.bedNumber || data?.code || id;
}

for (const [collection, module] of Object.entries(AUDITED)) {
  const name = "audit" + collection.split("_").map((p) => p[0].toUpperCase() + p.slice(1)).join("");
  exports[name] = onDocumentWritten(`${collection}/{docId}`, async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const docId = event.params.docId;
    let action;
    if (!before) action = "create";
    else if (!after) action = "delete";
    else if (before.status !== after.status && after.status) {
      action = after.status === "active" ? "activate" : "deactivate";
    } else action = collection === "roles" ? "update_permissions" : "update";

    const fields = changedFields(before, after);
    if (action === "update" && fields.length === 0) return;

    const actorUid = after?.updatedBy || before?.updatedBy || null;
    let actorName = null;
    if (actorUid) {
      const u = await db.doc(`users/${actorUid}`).get();
      actorName = u.exists ? u.get("displayName") : null;
    }
    // Only field NAMES are recorded, never values, to keep entries safe.
    await writeAudit({
      actorUid,
      actorName,
      action,
      module: collection === "system_settings" && docId === "backup" ? "backup" : module,
      collection,
      recordId: docId,
      recordLabel: recordLabel(after || before, docId),
      metadata: { changedFields: fields },
    });
  });
}

// Exposed only to unit tests, never to the deployed function set.
if (process.env.HMS_FUNCTIONS_TEST === "1") {
  exports._internal = { userAdminDenial, formatNumber, periodKey, changedFields };
}
