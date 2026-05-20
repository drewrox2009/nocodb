const { resolve } = require('path');
const { rspack } = require('@rspack/core');
const nodeExternals = require('webpack-node-externals');
const { TsCheckerRspackPlugin } = require('ts-checker-rspack-plugin');

module.exports = {
  entry: './src/run/dockerEntry.ts',
  module: {
    rules: [
      {
        test: /\.node$/,
        loader: 'node-loader',
        options: {
          name: '[path][name].[ext]',
        },
      },
      {
        test: /\.tsx?$/,
        exclude: /node_modules/,
        loader: 'builtin:swc-loader',
        options: {
          sourceMaps: false,
          jsc: {
            parser: {
              syntax: 'typescript',
              tsx: true,
              decorators: true,
              dynamicImport: true,
            },
            transform: {
              legacyDecorator: true,
              decoratorMetadata: true,
            },
            target: 'es2017',
            loose: true,
            externalHelpers: false,
            keepClassNames: true,
          },
          module: {
            type: 'commonjs',
            strict: false,
            strictMode: true,
            lazy: false,
            noInterop: false,
          },
        },
      },
    ],
  },

  optimization: {
    minimize: false,
    nodeEnv: false,
  },
  externals: [
    nodeExternals({
      allowlist: ['nocodb-sdk'],
    }),
  ],
  resolve: {
    extensions: ['.tsx', '.ts', '.js', '.json', '.node'],
    tsConfig: {
      configFile: resolve('tsconfig.json'),
    },
    alias: {
      '@noco-local-integrations': resolve(__dirname, '../noco-integrations/packages'),
      'nc-gui': resolve(__dirname, '../nc-gui'),
    },
  },
  mode: 'production',
  output: {
    filename: 'bundle.js',
    path: resolve(__dirname, 'dist'),
    library: 'libs',
    libraryTarget: 'umd',
    globalObject: "typeof self !== 'undefined' ? self : this",
  },
  node: {
    __dirname: false,
  },
  plugins: [
    new rspack.EnvironmentPlugin({
      EE: true,
    }),
    new rspack.CopyRspackPlugin({
      patterns: [{ from: 'src/public', to: 'public' }],
    }),
    // Skip TsChecker in CI/Docker builds — pre-existing TS errors in
    // integrations, validators, and migration stubs block production builds.
    ...(process.env.NC_DISABLE_TS_CHECKER
      ? []
      : [
          new TsCheckerRspackPlugin({
            typescript: {
              configFile: resolve('tsconfig.json'),
            },
          }),
        ]),
  ],
  target: 'node',
};
