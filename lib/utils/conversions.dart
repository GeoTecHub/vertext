double arpToHectares(double acres, double roods, double perches) {
  double totalAcres = acres + (roods / 4.0) + (perches / 160.0);
  return totalAcres * 0.40468564224;
}

Map<String, double> hectaresToARP(double hectares) {
  double totalAcres = hectares / 0.40468564224;
  int acres = totalAcres.floor();
  double remainingAcres = totalAcres - acres;
  double totalRoods = remainingAcres * 4.0;
  int roods = totalRoods.floor();
  double remainingRoods = totalRoods - roods;
  double perches = remainingRoods * 40.0;

  if (perches > 39.999) {
    perches = 0;
    roods += 1;
    if (roods >= 4) {
      roods = 0;
      acres += 1;
    }
  }

  return {
    'acres': acres.toDouble(),
    'roods': roods.toDouble(),
    'perches': perches,
  };
}
