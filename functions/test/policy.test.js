// Unit tests for pure helpers; firebase-admin is stubbed so no project is needed.
const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");

const stubs = {
  "firebase-functions/v2/https": { onCall: (f) => f, HttpsError: class extends Error {} },
  "firebase-functions/v2/firestore": { onDocumentWritten: (_p, f) => f },
  "firebase-functions/v2": { setGlobalOptions: () => {}, logger: console },
  "firebase-admin/app": { initializeApp: () => {} },
  "firebase-admin/auth": { getAuth: () => ({}) },
  "firebase-admin/firestore": { getFirestore: () => ({}), FieldValue: {} },
};
process.env.HMS_FUNCTIONS_TEST = "1";
const load = Module._load;
Module._load = (req, ...rest) => stubs[req] ?? load(req, ...rest);
const { _internal: m } = require("../index.js");
Module._load = load;

const caller = (role, perms = {}) => ({
  uid: "me",
  role,
  can: (mod, a) => role === "super_admin" || (perms[mod] || []).includes(a),
});

test("self-modification is always denied", () => {
  assert.ok(m.userAdminDenial(caller("super_admin"), "edit", { targetUid: "me" }));
});

test("admin cannot grant or modify privileged roles", () => {
  const admin = caller("admin", { users: ["view", "create", "edit", "deactivate"] });
  assert.ok(m.userAdminDenial(admin, "create", { newRole: "super_admin" }));
  assert.ok(m.userAdminDenial(admin, "edit", { targetUid: "x", targetRole: "admin", newRole: "doctor" }));
  assert.strictEqual(m.userAdminDenial(admin, "edit", { targetUid: "x", targetRole: "doctor", newRole: "lab_user" }), null);
});

test("roles without users permission are denied", () => {
  assert.ok(m.userAdminDenial(caller("receptionist"), "create", { newRole: "doctor" }));
});

test("number format matches the Dart implementation", () => {
  const d = { yyyy: "2026", mm: "03", dd: "09" };
  assert.strictEqual(m.formatNumber({ prefix: "OPD", separator: "-", dateSegment: "YYMM", padding: 5 }, 42, d), "OPD-2603-00042");
  assert.strictEqual(m.formatNumber({ prefix: "UHID", separator: "", dateSegment: "none", padding: 4 }, 7, d), "UHID0007");
  assert.strictEqual(m.periodKey("monthly", d), "2026-03");
  assert.strictEqual(m.periodKey("never", d), "all");
});

test("changedFields ignores metadata", () => {
  assert.deepStrictEqual(m.changedFields({ a: 1, updatedAt: 1 }, { a: 2, updatedAt: 2 }), ["a"]);
});
