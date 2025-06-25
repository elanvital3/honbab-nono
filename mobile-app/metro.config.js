const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');
const path = require('path');

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  resolver: {
    alias: {
      // Fix the module resolution issue
    },
  },
  watchFolders: [path.resolve(__dirname)],
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);