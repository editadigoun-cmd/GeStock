import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _busy = false;\n  bool _verificationPending = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final valid = await ref.read(authRepositoryProvider).hasValidSession();
    if (!mounted || !valid) return;
    final businesses = await ref.read(businessRepositoryProvider).list();
    if (!mounted) return;
    context.go(businesses.isEmpty ? '/business/setup' : '/home');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF063C35), Color(0xFF071D1A), Color(0xFF101C1A)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -90,
              child: _orb(260, GeStockColors.emerald.withValues(alpha: .15)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 470),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [GeStockColors.emerald, GeStockColors.deepEmerald],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: SvgPicture.asset('assets/brand/gestock_mark.svg'),
                            ),
                            const SizedBox(width: 13),
                            const Expanded(
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('GeStock', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                                Text('GESTION · STOCKS · PERFORMANCE', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFFB6D1C9), fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FCFA),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 32, offset: Offset(0, 16))],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isSignUp ? 'Créer un compte' : 'Connexion',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: GeStockColors.ink, letterSpacing: -.6),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _isSignUp ? 'Quelques informations pour commencer.' : 'Connectez-vous à votre espace GeStock.',
                                  style: const TextStyle(color: GeStockColors.muted, fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                if (_isSignUp) ...[
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization: TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                    decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline_rounded)),
                                    validator: (value) => (value == null || value.trim().length < 2) ? 'Saisissez votre nom complet.' : null,
                                  ),
                                  const SizedBox(height: 13),
                                ],
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Adresse e-mail', prefixIcon: Icon(Icons.mail_outline_rounded)),
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                                        ? null
                                        : 'Saisissez une adresse e-mail valide.';
                                  },
                                ),
                                const SizedBox(height: 13),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscurePassword,
                                  autofillHints: _isSignUp ? const [AutofillHints.newPassword] : const [AutofillHints.password],
                                  textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
                                  onFieldSubmitted: (_) => _isSignUp ? null : _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Saisissez votre mot de passe.';
                                    if (_isSignUp && value.length < 8) return '8 caractères minimum.';
                                    return null;
                                  },
                                ),
                                if (_isSignUp) ...[
                                  const SizedBox(height: 13),
                                  TextFormField(
                                    controller: _confirmation,
                                    obscureText: _obscureConfirmation,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'Confirmer le mot de passe',
                                      prefixIcon: const Icon(Icons.verified_user_outlined),
                                      suffixIcon: IconButton(
                                        tooltip: _obscureConfirmation ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                                        onPressed: () => setState(() => _obscureConfirmation = !_obscureConfirmation),
                                        icon: Icon(_obscureConfirmation ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                      ),
                                    ),
                                    validator: (value) => value != _password.text ? 'Les deux mots de passe ne correspondent pas.' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  const Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.shield_outlined, size: 16, color: GeStockColors.deepEmerald),
                                      SizedBox(width: 8),
                                      Expanded(child: Text('Utilisez au moins 8 caractères. Vous pourrez ensuite créer votre entreprise et définir ses paramètres.', style: TextStyle(color: GeStockColors.muted, fontSize: 11, height: 1.4))),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 54,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    child: _busy
                                        ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2))
                                        : Text(_isSignUp ? 'Créer mon compte' : 'Se connecter', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 2,
                                  children: [
                                    Text(
                                      _isSignUp ? 'Vous avez déjà un compte ?' : 'Vous découvrez GeStock ?',
                                      style: const TextStyle(color: GeStockColors.muted, fontSize: 12),
                                    ),
                                    TextButton(
                                      onPressed: _busy ? null : () => setState(() {
                                        _isSignUp = !_isSignUp;
                                        _formKey.currentState?.reset();
                                      }),
                                      child: Text(_isSignUp ? 'Se connecter' : 'Créer un compte', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'SÉCURISÉ  ·  MULTI-ENTREPRISES  ·  HORS LIGNE',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF8EAAA1), letterSpacing: 1, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 25)]),
      );

  Future<void> _forgotPassword() async {
    final email=_email.text.trim();
    if(!RegExp(r'^[^\\s@]+@[^\\s@]+\\.[^\\s@]+
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      if (_isSignUp) {
        await auth.signUp(_name.text.trim(), _email.text.trim(), _password.text);
        if (mounted) context.go('/business/setup');
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
        final businesses = await ref.read(businessRepositoryProvider).list();
        if (mounted) context.go(businesses.isEmpty ? '/business/setup' : '/home');
      }
    } catch (error) {
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('Failed host lookup') || message.contains('SocketException') || message.contains('No address associated with hostname')) {
      return 'Le serveur de connexion est momentanément injoignable. Vérifiez votre accès Internet puis réessayez. Si le problème persiste, le service d’authentification doit être vérifié.';
    }
    return message.replaceFirst('Exception: ', '').replaceFirst('DioException [bad response]: ', '');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 6)),
    );
  }
}
).hasMatch(email)){_showError('Saisissez votre adresse e-mail.');return;}
    setState(()=>_busy=true);
    try{await ref.read(authRepositoryProvider).requestPasswordReset(email);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Si ce compte existe, un e-mail de réinitialisation sera envoyé.')));}
    catch(e){_showError(_friendlyError(e));}finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _resendVerification() async {
    setState(()=>_busy=true);
    try{await ref.read(authRepositoryProvider).resendVerification();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('E-mail de vérification renvoyé.')));}
    catch(e){_showError(_friendlyError(e));}finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      if (_isSignUp) {
        await auth.signUp(_name.text.trim(), _email.text.trim(), _password.text);
        if (mounted) context.go('/business/setup');
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
        final businesses = await ref.read(businessRepositoryProvider).list();
        if (mounted) context.go(businesses.isEmpty ? '/business/setup' : '/home');
      }
    } catch (error) {
      _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('Failed host lookup') || message.contains('SocketException') || message.contains('No address associated with hostname')) {
      return 'Le serveur de connexion est momentanément injoignable. Vérifiez votre accès Internet puis réessayez. Si le problème persiste, le service d’authentification doit être vérifié.';
    }
    return message.replaceFirst('Exception: ', '').replaceFirst('DioException [bad response]: ', '');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 6)),
    );
  }
}
