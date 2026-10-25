import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/config/app_config.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/feedback.dart';

class _CenteredCard extends StatelessWidget {
  const _CenteredCard({required this.child, this.maxWidth = 440});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(Icons.local_hospital, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Text('HMS Admin Panel', style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = switch (e.code) {
          'invalid-credential' ||
          'wrong-password' ||
          'user-not-found' => 'Incorrect email or password.',
          'user-disabled' => 'This account has been deactivated.',
          'too-many-requests' => 'Too many attempts. Try again later.',
          _ => e.message ?? 'Sign-in failed (${e.code}).',
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _error = null;
        _info = 'If an account exists, a password reset email has been sent.';
      });
    } catch (e) {
      setState(() => _error = 'Could not send reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CenteredCard(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Brand(),
              const SizedBox(height: 24),
              Text('Sign in', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('Use the account issued by your administrator.'),
              const SizedBox(height: 24),
              if (_error != null) ...[
                InfoBanner(_error!, kind: BannerKind.danger),
                const SizedBox(height: 16),
              ],
              if (_info != null) ...[
                InfoBanner(_info!, kind: BannerKind.success),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v ?? '').contains('@') ? null : 'Enter a valid email',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Enter your password' : null,
                onFieldSubmitted: (_) => _signIn(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _reset,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetupRequiredPage extends ConsumerWidget {
  const SetupRequiredPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(backendProvider).error;
    final t = Theme.of(context).textTheme;
    return _CenteredCard(
      maxWidth: 680,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Brand(),
          const SizedBox(height: 24),
          Text('Firebase is not configured', style: t.headlineSmall),
          const SizedBox(height: 12),
          const InfoBanner(
            'The Admin Panel needs a Firebase project (Authentication, '
            'Cloud Firestore, Cloud Functions, optionally Storage). No '
            'credentials are bundled with the app.',
            kind: BannerKind.warning,
          ),
          const SizedBox(height: 16),
          const SelectableText(
            '1. Create a Firebase project and enable Email/Password sign-in.\n'
            '2. Run `flutterfire configure`, or pass options at build time:\n'
            '   flutter run --dart-define-from-file=firebase.env.json\n'
            '   (FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_PROJECT_ID,\n'
            '    FIREBASE_MESSAGING_SENDER_ID, FIREBASE_STORAGE_BUCKET,\n'
            '    FIREBASE_AUTH_DOMAIN)\n'
            '3. Deploy rules, indexes and functions: firebase deploy\n'
            '4. Create the first Super Admin with\n'
            '   functions/scripts/bootstrap-super-admin.js\n\n'
            'See docs/ADMIN_PANEL.md for full details.',
            style: TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text('Initialisation detail: $error', style: t.bodySmall),
          ],
          if (AppConfig.demoModeAllowed) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(backendProvider.notifier).enterDemoMode(),
              icon: const Icon(Icons.science_outlined),
              label: const Text(
                'Explore in demo mode (sample data, not saved)',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AccountInactivePage extends ConsumerWidget {
  const AccountInactivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider).value;
    final message = switch (s?.status) {
      'unprovisioned' =>
        'Your login exists but has no Admin Panel profile. Ask a Super '
            'Admin to create your account from the Users page.',
      'active' when s?.role == null =>
        'Your account has no role assigned yet. Ask an administrator to '
            'assign one, then sign in again.',
      _ => 'Your account is inactive. Contact an administrator.',
    };
    return _CenteredCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 24),
          InfoBanner(message, kind: BannerKind.warning),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: LoadingView(label: 'Loading session'));
}
