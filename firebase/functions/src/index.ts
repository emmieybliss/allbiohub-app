// AllBioHub community backend (COMMUNITY.md). Every function runs in
// REGION (core.ts); the app calls the same region.
import { setGlobalOptions } from "firebase-functions/v2";
import { REGION } from "./core.js";

setGlobalOptions({ region: REGION, maxInstances: 10 });

export { checkUsername, createProfile, updateProfile, changeUsername, onProfileUpdated } from "./profile.js";
export { setReaction } from "./reactions.js";
export { addComment, editComment, deleteComment, likeComment, onCommentWritten, moderateComment } from "./comments.js";
export { reportContent, blockUser, muteUser, resolveReport, setUserStatus } from "./safety.js";
export { setFollow, setSaved, importSaved } from "./follows.js";
export { votePoll, savePoll, closePoll, updatePollStatuses } from "./polls.js";
export {
  submitStory, submitStartup, claimStartup, reviewSubmission,
  onStorySubmissionUpdated, onStartupSubmissionUpdated, onStartupClaimUpdated,
} from "./submissions.js";
export { registerDevice, unregisterDevice, markAllNotificationsRead, updateNotificationPrefs } from "./notifications.js";
export { checkNewStories, checkStartupChanges } from "./alerts.js";
export { deleteAccount, claimAdmin } from "./account.js";
