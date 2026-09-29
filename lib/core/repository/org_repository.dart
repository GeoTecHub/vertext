import '../api/api_service.dart';

class OrgRepository {
  final _api = ApiService();

  Future<dynamic> details() => _api.getOrgDetails();
  Future<List<Map<String, dynamic>>> members() => _api.getOrgMembers();

  Future<List<Map<String, dynamic>>> subscriptionPlans() =>
      _api.getSubscriptionPlans();
  Future<dynamic> createSubscriptionPlan(Map<String, dynamic> plan) =>
      _api.createSubscriptionPlan(plan);
  Future<dynamic> updateSubscriptionPlan(int id, Map<String, dynamic> f) =>
      _api.updateSubscriptionPlan(id, f);

  Future<dynamic> createUser(Map<String, dynamic> u) => _api.createUser(u);
  Future<dynamic> createPublicAdmin(Map<String, dynamic> u) =>
      _api.createPublicAdmin(u);
  Future<dynamic> createInvitedUser(Map<String, dynamic> u) =>
      _api.createInvitedUser(u);
  Future<dynamic> updateUser(int id, Map<String, dynamic> f) =>
      _api.updateUser(id, f);
  Future<void> deleteUser(int id) => _api.deleteUser(id);
}
