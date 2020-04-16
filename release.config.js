module.exports = {
  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
    '@semantic-release/changelog',
    [
      '@semantic-release/git',
      {
        assets: ['CHANGELOG.md', 'package.json'],
        // NOTE: removed [skip ci] for now. If needed can be added later
        message:
          'chore(release): ${nextRelease.version} \n\n${nextRelease.notes}'
      }
    ],
    '@semantic-release/github'
  ]
};