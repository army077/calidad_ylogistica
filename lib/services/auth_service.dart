import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Login con Google + Firebase + guardado de token FCM
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();

      if (gUser == null) {
        // Usuario canceló login
        return null;
      }

      final GoogleSignInAuthentication gAuth =
          await gUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user != null) {
        await _saveFcmToken(user);
      }

      return userCredential;
    } catch (e) {
      print("Error en signInWithGoogle: $e");
      return null;
    }
  }

  /// Guardar token FCM en Firestore
  Future<void> _saveFcmToken(User user) async {
    try {
      final String? token =
          await FirebaseMessaging.instance.getToken();

      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('operadoresTokens')
          .doc(user.uid) // puedes cambiar a user.email si prefieres
          .set({
            'email': user.email,
            'fcmTokens': FieldValue.arrayUnion([token]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print("Error guardando token FCM: $e");
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Usuario actual
  User? get currentUser => _auth.currentUser;
}
