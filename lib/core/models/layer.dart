class LayerModel {
  final int layerId;
  final int userId;
  final String layerName;
  final String colour;
  final String dateCreated;
  final bool visible;

  LayerModel({
    required this.layerId,
    required this.userId,
    required this.layerName,
    required this.colour,
    required this.dateCreated,
    required this.visible,
  });

  factory LayerModel.fromJson(Map<String, dynamic> j) => LayerModel(
    layerId: j['layer_id'],
    userId: j['user_id'],
    layerName: j['layer_name'],
    colour: j['colour'],
    dateCreated: j['date_created'],
    visible: (j['visible'] ?? true) == true,
  );

  Map<String, dynamic> toJson() => {
    'layer_id': layerId,
    'user_id': userId,
    'layer_name': layerName,
    'colour': colour,
    'date_created': dateCreated,
    'visible': visible,
  };
}
