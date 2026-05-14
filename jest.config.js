module.exports = {
  preset: 'react-native',
  testPathIgnorePatterns: ['/node_modules/', '/ios/', '/android/'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@testing-library/react-native|expo(nent)?|@expo(nent)?/.*|expo-router|@expo-google-fonts/.*)/)',
  ],
};
