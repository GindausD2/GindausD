export const Colors = {
  background: '#F4F1EB', surface: '#FAF8F4', card: '#FFFFFF', cardHover: '#EEEAE3', inputBg: '#EFEBE5',
  primary: '#292D2B', primaryLight: '#59615A', primaryDark: '#191C1A', secondary: '#778578', secondaryLight: '#596F60', accent: '#B69B72',
  userBubble: '#E4E8E1', userBubbleText: '#292D2B', aiBubble: '#FFFFFF', aiBubbleText: '#292D2B',
  textPrimary: '#292D2B', textSecondary: '#686D67', textMuted: '#777C76', textLink: '#596F60',
  border: '#DEDCD5', borderFocus: '#596F60', success: '#596F60', warning: '#967342', error: '#AB433B',
  overlay: 'rgba(24,28,25,0.28)', shimmer: 'rgba(255,255,255,0.45)', gradientStart: '#F7F5EF', gradientEnd: '#DCE4DB', statusBar: 'dark',
} as const;
export type ColorKey = keyof typeof Colors;
