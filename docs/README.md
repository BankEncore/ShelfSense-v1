# ShelfSense documentation

This directory contains the project’s technical authority, development guidance, and implementation documentation.

## Start here

| Document | Purpose |
|---|---|
| [Architecture Decision Records](adr/README.md) | Accepted and proposed cross-cutting architecture decisions |
| [Development guide](development.md) | Local setup, PostgreSQL configuration, application commands, and troubleshooting |
| [Testing and CI](testing.md) | Active GitHub Actions checks and prerequisites for deferred checks |
| [Project README](../README.md) | Project purpose, status, roadmap, architecture summary, and quick start |
| [Contributor rules](../AGENTS.md) | Required practices for human contributors and coding agents |

## Document authority

Accepted ADRs govern implementation. Proposed ADRs describe unresolved policy and must not be treated as final. When code or another document conflicts with an accepted ADR, resolve the conflict explicitly—normally with a superseding ADR—rather than allowing silent divergence.

Update the relevant documentation in the same change as behavior, schema, terminology, permissions, workflows, deployment requirements, or CI coverage.

## Planned documentation areas

As implementation advances, this index should link the canonical documents for:

- Domain models and boundaries
- Operational workflows
- Schema reference or data dictionary
- Security and privacy
- Glossary
- Roadmap and implementation status
- Deployment and operations

Add a document only when it has a clear owner and purpose. Prefer linking one canonical source over duplicating policy across several files.
