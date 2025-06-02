import 'package:mockito/mockito.dart';
import 'package:betullarise/database/rewards_database_helper.dart';
import 'package:betullarise/model/reward.dart';

class MockRewardsDatabaseHelper extends Mock implements IRewardsDatabaseHelper {
  List<Reward> mockRewards = [];

  @override
  Future<List<Reward>> getAllRewards() async {
    return mockRewards;
  }
}
