module.exports = {
  root: true,
  env: {
    node: true,
    es2021: true,
    mocha: true,
  },
  ignorePatterns: ["lib/", "frontend/"],
  parser: "@typescript-eslint/parser",
  plugins: ["@typescript-eslint"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:prettier/recommended",
  ],
  rules: {
    "@typescript-eslint/no-explicit-any": "off",
  },
};
