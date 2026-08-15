# Contributing to Khair

Welcome! Thank you for helping build Khair. We want to make contributing to this project as easy and transparent as possible.

## Branch Strategy

We follow a structured branching model to protect production:

*   **`main`**: Production-ready code. Commits here go directly to users. **Never commit directly to `main`.**
*   **`develop`**: The main integration branch for the next release.
*   **Work branches**: Created off `develop` for specific tasks:
    *   `feature/<name>`: New features
    *   `fix/<name>`: Bug fixes
    *   `refactor/<name>`: Code refactoring without behavioral changes
    *   `chore/<name>`: Configuration, tooling, or minor maintenance
    *   `docs/<name>`: Documentation updates

## Workflow

1.  **Sync your local `develop` branch:**
    ```bash
    git checkout develop
    git pull origin develop
    ```
2.  **Create your work branch:**
    ```bash
    git checkout -b feature/awesome-new-thing
    ```
3.  **Implement your changes.**
    *   Write clean, readable code.
    *   Add or update tests as necessary.
    *   Ensure no secrets or credentials are hardcoded.
4.  **Verify your work locally:**
    *   Backend: `cd backend && go test ./...` and `go build ./...`
    *   Frontend: `cd frontend/khair_app && flutter analyze` and `flutter test`
5.  **Commit your changes using Conventional Commits:**
    ```bash
    git add .
    git commit -m "feat(events): add map clustering for nearby events"
    ```
6.  **Push your branch:**
    ```bash
    git push -u origin feature/awesome-new-thing
    ```
7.  **Open a Pull Request (PR):**
    *   Target the `develop` branch.
    *   Fill out the PR template completely.
    *   Wait for CI checks to pass and request a code review.
8.  **Merge!** Once approved, the PR will be squash-merged into `develop`.

## Commit Message Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/).

Format: `<type>(<scope>): <subject>`

**Types:**
*   `feat`: A new feature
*   `fix`: A bug fix
*   `docs`: Documentation only changes
*   `style`: Changes that do not affect the meaning of the code (white-space, formatting, etc.)
*   `refactor`: A code change that neither fixes a bug nor adds a feature
*   `perf`: A code change that improves performance
*   `test`: Adding missing tests or correcting existing tests
*   `chore`: Changes to the build process or auxiliary tools and libraries

**Examples:**
*   `feat(auth): integrate Google Sign-In`
*   `fix(map): resolve null pointer exception when location disabled`
*   `chore: update flutter SDK to 3.2`

## Database Migrations

If you are changing the database schema:
1.  **Never modify an existing migration** that has been applied to production.
2.  Create a new up/down migration pair in `backend/migrations/` following the existing numbered sequence (e.g., `050_add_new_table.up.sql`).
3.  Explain the migration in your PR, especially if it involves destructive operations (DROP, ALTER COLUMN) or large table scans.

## Cleanup

Please delete your branch remotely and locally after your PR is merged to keep the repository clean.
