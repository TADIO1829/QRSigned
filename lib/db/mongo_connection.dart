import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {

  static final String _uri = 'mongodb://localhost:27017/qrsigned';
  static Db? _db;

  static Future<Db> connect() async {
    if (_db == null || !_db!.isConnected) {
      _db = Db(_uri);
      await _db!.open();
    }
    return _db!;
  }
}
