import * as ImagePicker from 'expo-image-picker';
import { showMessage } from '@/lib/toast';

const MAX_BYTES = 5 * 1024 * 1024;

/** Picks a picture from the gallery (square when [square]). Null when cancelled or over 5 MB. */
export async function pickImage(square = false): Promise<{ uri: string; type: string } | null> {
  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images'],
    quality: 0.85,
    allowsEditing: square,
    aspect: square ? [1, 1] : undefined,
  });
  const asset = result.canceled ? null : result.assets[0];
  if (!asset) return null;
  if (asset.fileSize && asset.fileSize > MAX_BYTES) {
    showMessage('Choose an image under 5 MB.');
    return null;
  }
  const type = asset.mimeType ?? (asset.uri.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  return { uri: asset.uri, type };
}
