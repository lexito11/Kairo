/// Límites de chat acordados para KAIRO.
abstract final class ChatLimits {
  static const maxPinnedChats = 5;
  static const maxGroupsCreatedPerUser = 5;
  static const maxMembersPerGroup = 5000;
  static const maxAdminsPerGroup = 3;
  static const minInviteesToCreateGroup = 3;
  static const maxGroupDescriptionLength = 280;
  static const maxGroupImageBytes = 5 * 1024 * 1024;
}
