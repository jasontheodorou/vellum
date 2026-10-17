# Security

## Reporting a problem

Please do not report security problems in a public issue.

Use GitHub's private reporting instead: on this repository, open the **Security** tab and choose **Report a vulnerability**. You should get a reply within seven days.

## What counts

These are especially important to us:

- the background helper writing outside the project's `.scribe/` folder, running commands or reaching the network
- a journal ending up in git, or anywhere other than your own computer
- `scribe remove-old-install` or `scribe migrate` changing files they should not touch

## Supported versions

Only the latest release gets security fixes. Versions before 1.0, which were installed with the curl script, are no longer supported. Ask Claude to "remove the old Scribe install" to remove one.
