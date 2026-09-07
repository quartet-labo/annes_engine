# Changelog

## 0.1.0

- Extract the inquiry engine from anne-mark into this repository as an independent package.
- Preserve the AnnesInquiry API, table names, five migration sources, and host adapter contracts.
- Include versioned form administration, typed answers, validation, submission replay protection,
  shared attachments, notification requests, and cleanup services.
- Add standalone PostgreSQL and browser tests, package metadata, and GitHub Packages release support.
- Stop public submission processing when the context hook renders or redirects a denial.
- Reject excessive attachment counts before inspecting or hashing file contents.
