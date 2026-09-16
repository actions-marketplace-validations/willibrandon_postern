# Security Policy

## Reporting a vulnerability

Please report security issues privately through the repository's GitHub
security advisory form. Do not open a public issue with credentials,
connection strings, or an exploit.

Include the affected version, reproduction steps, and impact when possible.
Reports will be acknowledged as soon as practical.

## Scope

Postern can connect to PostgreSQL and can issue administrative commands when a
client invokes its live code actions. Use least-privileged database credentials
and review live actions before applying them.
