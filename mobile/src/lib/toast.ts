import { Alert, Platform, ToastAndroid } from 'react-native';

/** A short message at the bottom of the screen (Android) or an alert (elsewhere). */
export function showMessage(message: string) {
  if (Platform.OS === 'android') ToastAndroid.show(message, ToastAndroid.LONG);
  else Alert.alert(message);
}
