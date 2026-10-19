# Security

## Reporting a problem

Please do not report security problems in a public issue.

Use GitHub's private reporting if it is available: on this repository, open the **Security** tab and choose **Report a vulnerability**. If you do not see that option, [open an issue](https://github.com/jasontheodorou/vellum/issues) asking for a contact, without any details of the problem. You should get a reply within seven days.

## What counts

These are especially important to us:

- the curator writing outside the project's `.vellum/` folder, running commands or reaching the network
- a journal ending up in git, or anywhere other than your own computer
- `install.sh`, `vellum remove-old-install` or `vellum migrate` changing files they should not touch

## Supported versions

Only the latest release gets security fixes. Version 0.10 is supported. Versions 0.1.8 and earlier, which were installed with the old Scribe curl script, are no longer supported. Run the Vellum installer, or ask Claude to "remove the old Scribe install", to remove one.
