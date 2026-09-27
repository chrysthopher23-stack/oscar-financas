abstract interface class PrintGateway {
  Future<void> printDocument(List<int> bytes);
}

abstract interface class ShareGateway {
  Future<void> shareDocument(List<int> bytes, String fileName);
}
