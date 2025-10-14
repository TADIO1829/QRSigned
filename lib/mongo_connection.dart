import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  //static final String _uri = 'mongodb://192.168.100.61:27017/login_app';
  static final String _uri = 'mongodb://localhost:27017/qrsigned';
  //static final String _uri = 'mongodb+srv://adriancadena:Cadenatadeo1@cluster0.ak6x1jm.mongodb.net/qrapp';
  static Db? _db;

  static Future<Db> connect() async {
    if (_db == null || !_db!.isConnected) {
      _db = Db(_uri);
      await _db!.open();
    }
    return _db!;
  }
}
