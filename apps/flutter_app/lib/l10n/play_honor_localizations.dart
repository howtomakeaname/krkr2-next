import '../models/play_insights.dart';
import 'app_localizations.dart';

extension PlayHonorLocalizations on AppLocalizations {
  String playHonorTier(PlayHonorTier tier) => switch (tier) {
    PlayHonorTier.newcomer => profileHonorNewcomer,
    PlayHonorTier.storyTraveler => profileHonorStoryTraveler,
    PlayHonorTier.immersedReader => profileHonorImmersedReader,
    PlayHonorTier.veteran => profileHonorVeteran,
    PlayHonorTier.collector => profileHonorCollector,
    PlayHonorTier.curator => profileHonorCurator,
  };

  String playHonorRequirement(PlayHonor honor, String remainingDuration) {
    if (honor.nextTier == null) return profileHonorHighest;
    if (honor.remainingSeconds > 0 && honor.remainingGames > 0) {
      return profileHonorRemainingBoth(remainingDuration, honor.remainingGames);
    }
    if (honor.remainingSeconds > 0) {
      return profileHonorRemainingTime(remainingDuration);
    }
    return profileHonorRemainingGames(honor.remainingGames);
  }
}
