import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { PixelRatio, type StyleProp, View, type ViewStyle, type ImageStyle } from 'react-native';
import { imageUrlFor } from '@/lib/images';
import type { MediaImage } from '@/models/types';
import { usePalette } from '@/theme';

/**
 * Downloads the smallest WordPress rendition that's sharp at [width] (dp),
 * cached on disk by expo-image. Falls back to a branded placeholder.
 */
export function AppImage({
  image,
  width,
  style,
  allowCropped,
  rounded,
}: {
  image?: MediaImage;
  width: number;
  style?: StyleProp<ImageStyle>;
  allowCropped?: boolean;
  rounded?: number;
}) {
  const p = usePalette();
  if (!image) {
    return (
      <View
        style={[{ backgroundColor: p.accentSoft, alignItems: 'center', justifyContent: 'center', borderRadius: rounded }, style as StyleProp<ViewStyle>]}
        accessible={false}
      >
        <Ionicons name="image-outline" size={24} color={p.accentText} />
      </View>
    );
  }
  const uri = imageUrlFor(image, PixelRatio.getPixelSizeForLayoutSize(width), allowCropped);
  return (
    <Image
      source={{ uri }}
      style={[{ backgroundColor: p.skeleton, borderRadius: rounded }, style]}
      contentFit="cover"
      transition={150}
      cachePolicy="memory-disk"
      accessibilityLabel={image.alt || undefined}
      accessible={!!image.alt}
      recyclingKey={uri}
    />
  );
}
