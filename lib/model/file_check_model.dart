class FileCheckModel {
  String? labelHash;
  String? modelHash;

  FileCheckModel({this.labelHash, this.modelHash});

  FileCheckModel.fromJson(Map<String, dynamic> json) {
    labelHash = json['label_hash'];
    modelHash = json['model_hash'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['label_hash'] = this.labelHash;
    data['model_hash'] = this.modelHash;
    return data;
  }
}
