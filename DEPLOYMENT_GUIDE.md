# Deploying Notesy

## The situation

Notesy has been living on one engineer's laptop since it was built. It works, people use it, but the only way to run it right now is "clone the repo, hope your Python and Node versions line up, and remember the seed command." There's a `.github/workflows/ci.yml` in the repo, but it barely does anything — it installs dependencies and runs `pytest || true`, which means it reports green even when tests fail.

You've been asked to take this from "runs on my laptop" to "runs in a container, builds itself, and publishes an image the rest of the team can actually pull and run."

One wrinkle: the team is mid-migration on container registries. Everything has lived in **JFrog Artifactory** for the last couple of years, but new services are landing in **AWS ECR**, and nobody wants to flip the switch on the rest of the team's tooling until both are proven out. So for now, every image you build needs to land in **both** registries, tagged the same way, so either one can be pointed at for a deploy.

Nobody's asking you to touch how the app itself works. This is an infrastructure task.

---

## What you're starting with

```
.
├── manage.py
├── notesy/                  # Django project (settings, urls, wsgi/asgi)
├── apps/notes/              # the app itself — models, views, templates
│   └── static_src/          # TypeScript source for the small client bundle
├── package.json             # esbuild + tsc toolchain
├── requirements.txt
├── pytest.ini
├── .github/workflows/ci.yml # exists, but isn't doing its job yet
└── README.md
```

The app currently defaults to SQLite and reads a couple of config values (`SECRET_KEY`, `DEBUG`) as hardcoded values in `notesy/settings.py`. You'll need to parameterize those via environment variables before this is something you can safely put in an image — a container that only works with one hardcoded secret and one hardcoded debug flag isn't really deployable. That's expected prep work for Milestone 1, not a separate task.

---

## Milestone 1 — Containerize it

Get the whole stack running with one command, on Postgres, with nothing installed on the host except Docker.

- A `Dockerfile` that builds the TypeScript bundle and the Python app. Multi-stage is the right call here — you don't want Node in your final runtime image.
- A `docker-compose.yml` with the app and a Postgres service. `docker compose up --build` should be enough to get a working stack; migrations should run automatically on startup.
- Config (secret key, debug flag, database URL, allowed hosts) should come from environment variables, not be hardcoded. Local dev values can live in `docker-compose.yml` directly or a `.env` file that's **not** committed to git.
- Run as a non-root user inside the container.

**Done looks like:** a teammate with only Docker installed can clone the repo, run one command, and log in at `localhost:8000` as `demo`/`demo`.

---

## Milestone 2 — Automate the build

Fix the existing `.github/workflows/ci.yml` so it's a pipeline you'd actually trust.

- Tests should run against real Postgres in CI (a services container), not SQLite — the whole point is catching things that only break against the database you actually run in production.
- A failing test should fail the workflow. No `|| true`.
- The frontend bundle should build and typecheck in CI too, not just the Python side.
- The Docker image should build in CI as a check on every PR, even before you wire up publishing.

---

## Milestone 3 — Publish to both registries

On merge to `main`, the pipeline should build the image once and push it to **both** ECR and JFrog Artifactory, using the same tag in both places.

- Tag by commit SHA (in addition to a floating tag like `latest`), so you can always point a deploy at an exact, known build — this is what makes a rollback possible.
- Use OIDC role assumption for AWS auth, not long-lived access keys stored as a static GitHub secret.
- For JFrog, you'll need an access token (or username/password) stored as GitHub secrets, and your Artifactory instance's Docker registry URL.

**Setting up the registries (one-time, do this first):**
- **ECR**: create a repository (`aws ecr create-repository --repository-name notesy`), and set up an IAM role trusted for GitHub's OIDC provider with push permissions to it.
- **JFrog**: a free Artifactory Cloud instance is enough for this — create a Docker repository in it and generate an access token scoped to push images.
- Store `AWS_ECR_DEPLOY_ROLE_ARN`, `JFROG_URL`, `JFROG_USERNAME`, and `JFROG_ACCESS_TOKEN` (or equivalent) as GitHub Actions secrets.

---

## Stretch goal — Deploy it

Once Compose and the dual-registry publish are both solid, write the Kubernetes manifests (`Deployment`, `Service`, and a `ConfigMap`/`Secret` for config) and get the app actually running on a cluster — a local one (`kind` or `minikube`) is completely fine for this. Point the `Deployment`'s image at whichever registry you like; the point is proving the same image that CI publishes is the one running in the cluster.

This is optional. Don't burn your Milestone 1–3 quality trying to get here.

---

## Your `DEPLOY.md`

Add a `DEPLOY.md` at the repo root covering:

1. **What you built** — one section per milestone, brief is fine.
2. **Tradeoffs** — anywhere you picked one approach over another, and what the alternative was.
3. **How to run it** — the exact command(s), if `docker compose up --build` isn't the whole story.
4. **Keeping two registries in sync** — what happens if the push to one registry succeeds and the other fails mid-pipeline? What's your story for detecting and fixing drift between what's in ECR versus what's in JFrog?
5. **Rollback** — given an image tagged by commit SHA in both registries, how would you actually roll back a bad release? What has to change, and where?
6. **If you attempted the stretch goal** — how would you get from a local `kind`/`minikube` cluster to a real one? What would need to change (image pull secrets, ingress, resource limits) that a local cluster lets you skip?

---

## Definition of done

- [ ] `docker compose up --build` gets a working app on Postgres, no host setup beyond Docker
- [ ] No hardcoded secrets or debug flags in the image — all config comes from the environment
- [ ] CI runs tests against Postgres and actually fails on a failing test
- [ ] CI builds the frontend bundle and runs the typecheck
- [ ] On merge to `main`, the image is built once and pushed to both ECR and JFrog Artifactory, tagged by commit SHA
- [ ] AWS auth in CI uses OIDC, not static keys
- [ ] `DEPLOY.md` is written
- [ ] *(stretch)* the app is running on a Kubernetes cluster, local or otherwise
