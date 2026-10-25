#!/usr/bin/env node
/**
 * One-time bootstrap: creates (or promotes) the first Super Admin and seeds
 * the default role documents. Run by an operator with project credentials:
 *
 *   gcloud auth application-default login      (or set GOOGLE_APPLICATION_CREDENTIALS)
 *   cd functions && npm install
 *   node scripts/bootstrap-super-admin.js <project-id> <email> "<Display Name>"
 *
 * Prints a one-time password setup link. No password is ever passed on the
 * command line or stored in Firestore.
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const defaultRoles = require("../default_roles.json");

async function main() {
  const [projectId, emailArg, displayName] = process.argv.slice(2);
  if (!projectId || !emailArg || !displayName) {
    console.error('Usage: node scripts/bootstrap-super-admin.js <project-id> <email> "<Display Name>"');
    process.exit(1);
  }
  const email = emailArg.trim().toLowerCase();
  initializeApp({ credential: applicationDefault(), projectId });
  const auth = getAuth();
  const db = getFirestore();

  let user;
  try {
    user = await auth.getUserByEmail(email);
    console.log(`Found existing account ${user.uid}; promoting to Super Admin.`);
  } catch {
    user = await auth.createUser({ email, displayName });
    console.log(`Created account ${user.uid}.`);
  }
  await auth.setCustomUserClaims(user.uid, { role: "super_admin" });
  await db.doc(`users/${user.uid}`).set(
    {
      displayName,
      email,
      role: "super_admin",
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: "bootstrap",
      updatedBy: "bootstrap",
    },
    { merge: true },
  );

  for (const [roleId, def] of Object.entries(defaultRoles)) {
    const ref = db.doc(`roles/${roleId}`);
    if ((await ref.get()).exists) continue;
    await ref.set({ ...def, updatedAt: FieldValue.serverTimestamp(), updatedBy: "bootstrap" });
    console.log(`Seeded role ${roleId}.`);
  }

  await db.collection("audit_logs").add({
    timestamp: FieldValue.serverTimestamp(),
    actorUid: null,
    actorName: "Bootstrap script",
    action: "bootstrap_super_admin",
    module: "users",
    collection: "users",
    recordId: user.uid,
    recordLabel: email,
    result: "success",
    metadata: {},
  });

  const link = await auth.generatePasswordResetLink(email);
  console.log("\nSuper Admin ready. Password setup link (share securely):\n" + link);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
