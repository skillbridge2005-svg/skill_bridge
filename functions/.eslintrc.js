module.exports = {
  env: {
    es6: true,
    node: true,
  },

  parserOptions: {
    ecmaVersion: 2022,
  },

  extends: [
    "eslint:recommended",
    "google",
  ],

  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": [
      "error",
      "double",
      {
        allowTemplateLiterals: true,
      },
    ],

    // Allow longer strings for AI prompts.
    "max-len": [
      "error",
      {
        code: 100,
        ignoreUrls: true,
        ignoreStrings: true,
        ignoreTemplateLiterals: true,
      },
    ],

    // Do not require JSDoc on every helper function.
    "require-jsdoc": "off",

    // Avoid legacy JSDoc validation errors.
    "valid-jsdoc": "off",

    // Avoid Windows CRLF line-ending lint errors.
    "linebreak-style": "off",
  },

  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],

  globals: {},
};
