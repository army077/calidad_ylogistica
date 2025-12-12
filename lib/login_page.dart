// ignore_for_file: use_build_context_synchronously

// import 'package:sistema_rastreabilidad/componentes/squeare_tile.dart';
import 'package:sistema_rastreabilidad/componentes/my_botton.dart';
import 'package:sistema_rastreabilidad/componentes/my_textfield.dart';
import 'package:sistema_rastreabilidad/restablecer_contrasena.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final Function()? onTap;
  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

void googleSignInFunction() {
  AuthService().signInWithGoogle();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void iniciarsesion() async {
    showDialog(
        context: context,
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        showCustomSnackBar(
          context,
          'Usuario o contraseña incorrecta',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      } else {
        showCustomSnackBar(
          context,
          'Ingresa los campos correctamente',
        );
      }
    } catch (e) {
      showCustomSnackBar(
        context,
        'Ocurrió un error al iniciar sesión ',
      );
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void showCustomSnackBar(BuildContext context, String message,
      {Color backgroundColor = Colors.black, Color textColor = Colors.white}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                  image: AssetImage('lib/images/portada_ar.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Color.fromARGB(115, 70, 67, 67), BlendMode.darken)),
            ),
          ),
          Opacity(
            opacity: 0.6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 10,
                    ),
                    Image.asset(
                      'lib/images/logo_ar_bl_sombra.png',
                      height: 59,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    const Text(
                      '¡Logistica y Calidad AR!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                        color: Color.fromRGBO(255, 255, 255, 1),
                      ),
                    ),
                    const SizedBox(
                      height: 50,
                    ),
                    const SizedBox(height: 50),
                    MyTextField(
                      controller: emailController,
                      hintText: 'Email',
                      obscureText: false,
                    ),
                    const SizedBox(height: 30),
                    MyTextField(
                      controller: passwordController,
                      hintText: 'Contraseña',
                      obscureText: true,
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PasswordResetPage()),
                              );
                            },
                            child: Text(
                              'Restablecer la contraseña?',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    MyButton(
                      text: "Iniciar Sesion",
                      onTap: iniciarsesion,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                            child: Divider(
                          thickness: 0.5,
                          color: Colors.grey[400],
                        )),
                        Text(
                          'O',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Expanded(
                          child: Divider(
                            thickness: 0.5,
                            color: Colors.grey[400],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: googleSignInFunction,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        width: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(24),
                          color: const Color.fromRGBO(255, 255, 255, 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: Image.asset(
                                'lib/images/google_sign_in.png',
                                height: 32,
                              ),
                            ),
                            const Text(
                              'Entrar con Google',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No registrado?',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: widget.onTap,
                          child: const Text(
                            'Registrar',
                            style: TextStyle(
                              color: Color(0xFF1e3a5d),
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    )
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}
