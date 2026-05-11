/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{js,ts,tsx}', './components/**/*.{js,ts,tsx}'],

  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      colors: {
        dark: {
          background: '#090A12',
          surface: '#121421',
          'surface-elevated': '#1A1D2E',
          'surface-muted': '#202337',
          border: '#2A2D3D',
          'border-strong': '#3A3D52',
          'text-primary': '#F8FAFC',
          'text-secondary': '#A1A1AA',
          'text-muted': '#71717A',
        },
        brand: {
          primary: '#7C3AED',
          'primary-pressed': '#6D28D9',
          'primary-soft': '#2E1B5F',
          'primary-light': '#A78BFA',
        },
        status: {
          success: '#22C55E',
          'success-soft': '#12351F',
          warning: '#F59E0B',
          'warning-soft': '#3A2606',
          danger: '#EF4444',
          'danger-soft': '#3B1212',
          info: '#38BDF8',
        },
      },
      fontFamily: {
        display: ['BebasNeue_400Regular'],
        body: ['Inter_400Regular'],
        'body-medium': ['Inter_500Medium'],
        'body-semibold': ['Inter_600SemiBold'],
        'body-bold': ['Inter_700Bold'],
      },
      fontSize: {
        display: ['32px', { lineHeight: '38px' }],
        h1: ['28px', { lineHeight: '34px' }],
        h2: ['24px', { lineHeight: '30px' }],
        h3: ['20px', { lineHeight: '26px' }],
        'body-lg': ['18px', { lineHeight: '28px' }],
        body: ['16px', { lineHeight: '24px' }],
        'body-sm': ['14px', { lineHeight: '20px' }],
        caption: ['12px', { lineHeight: '16px' }],
        micro: ['11px', { lineHeight: '14px' }],
      },
    },
  },
  plugins: [],
};
