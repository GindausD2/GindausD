export const Colors = {
  // Backgrounds
  background: '#0A0A0F',
  surface: '#12121A',
  card: '#1A1A2E',
  cardHover: '#1E1E35',
  inputBg: '#16162A',

  // Brand
  primary: '#7C3AED',
  primaryLight: '#9D5FFF',
  primaryDark: '#5B21B6',
  secondary: '#06B6D4',
  secondaryLight: '#22D3EE',
  accent: '#F59E0B',

  // Messages
  userBubble: '#7C3AED',
  userBubbleText: '#FFFFFF',
  aiBubble: '#1E293B',
  aiBubbleText: '#F1F5F9',

  // Text
  textPrimary: '#F1F5F9',
  textSecondary: '#94A3B8',
  textMuted: '#64748B',
  textLink: '#7C3AED',

  // System
  border: '#1E293B',
  borderFocus: '#7C3AED',
  success: '#10B981',
  warning: '#F59E0B',
  error: '#EF4444',

  // Overlays
  overlay: 'rgba(0,0,0,0.7)',
  shimmer: 'rgba(255,255,255,0.05)',

  // Gradients (as stops)
  gradientStart: '#7C3AED',
  gradientEnd: '#06B6D4',

  // Status bar
  statusBar: 'light',
} as const;

export type ColorKey = keyof typeof Colors;
