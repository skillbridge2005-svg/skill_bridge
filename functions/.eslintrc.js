
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
<<<<<<< HEAD
    "quotes": ["error", "double", {allowTemplateLiterals: true}],

    // Avoid blocking deployment for existing formatting and documentation issues.
    "max-len": "off",
    "require-jsdoc": "off",
=======
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
>>>>>>> origin/main
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
