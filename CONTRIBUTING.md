# Contributing to Aptly HA Cluster

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check [existing issues](https://github.com/TazoTandilashvili/aptly-ha-cluster/issues) to avoid duplicates
2. Create a new issue with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (OS, versions, etc.)
   - Relevant logs or screenshots

### Submitting Changes

1. **Fork the repository**
   ```bash
   git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
   cd aptly-ha-cluster
   git checkout -b feature/my-feature
   ```

2. **Make your changes**
   - Follow existing code style
   - Add comments for complex logic
   - Update documentation if needed
   - Test your changes thoroughly

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add feature: description"
   ```
   
   Use clear commit messages:
   - `feat: Add support for Ubuntu 24.04`
   - `fix: Correct HAProxy health check timeout`
   - `docs: Update installation guide`
   - `refactor: Simplify GPG key generation`

4. **Push and create Pull Request**
   ```bash
   git push origin feature/my-feature
   ```
   
   Then open a PR on GitHub with:
   - Description of changes
   - Related issue numbers
   - Testing performed
   - Screenshots (if applicable)

## Development Guidelines

### Bash Scripts

- Use `#!/bin/bash` (not sh)
- Include `set -e` for error handling
- Add comments for non-obvious code
- Use meaningful variable names
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

Example:
```bash
#!/bin/bash
set -e

# Constants in UPPER_CASE
REPO_URL="http://example.com"

# Functions with descriptive names
install_dependencies() {
    log_info "Installing packages..."
    apt-get install -y package1 package2
}

# Main execution
main() {
    install_dependencies
    configure_system
}

main "$@"
```

### Documentation

- Use Markdown for all docs
- Keep lines under 100 characters
- Include code examples
- Add table of contents for long docs
- Test all commands before documenting

### Configuration Files

- Provide `.example` templates
- Never commit sensitive data
- Document all configuration options
- Use comments for complex settings

## Testing

Before submitting:

1. **Test standalone deployment**
   ```bash
   cd standalone
   sudo ./deploy.sh
   ```

2. **Test HA cluster deployment**
   ```bash
   cd ha-cluster
   # Deploy on test VMs
   ```

3. **Verify documentation**
   - Check all links work
   - Verify commands are accurate
   - Test on fresh Ubuntu 22.04

4. **Run shellcheck** (if available)
   ```bash
   shellcheck standalone/deploy.sh
   ```

## Code Review Process

1. Maintainers will review your PR
2. Address any requested changes
3. Once approved, we'll merge your PR
4. Your contribution will be credited

## Feature Requests

We welcome feature suggestions! Consider:

- Is it useful for most users?
- Does it fit the project scope?
- Can it be implemented maintainably?
- Have you considered alternatives?

Good candidates:
- Support for new Ubuntu versions
- Additional deployment options
- Monitoring integrations
- Automation improvements

## Style Guide

### Shell Scripts

```bash
# Good
log_info "Starting deployment..."
PACKAGE_URL="http://example.com/package.deb"

# Bad
echo "starting deployment"
packageURL="http://example.com/package.deb"
```

### Markdown

```markdown
# Good
## Section Title

Description paragraph.

### Subsection

- List item 1
- List item 2

# Bad
##Section Title
Description paragraph without spacing.
###Subsection
* inconsistent bullet style
```

### Configuration

```bash
# Good - with comments
{
    "rootDir": "/var/aptly",           # Base directory
    "downloadConcurrency": 4,           # Parallel downloads
    "architectures": ["amd64"]          # Supported architectures
}

# Bad - no explanation
{
    "rootDir": "/var/aptly",
    "downloadConcurrency": 4,
    "architectures": ["amd64"]
}
```

## Community

- Be respectful and inclusive
- Help others learn
- Share knowledge
- Acknowledge contributions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

- Open an issue for general questions
- Email: support@yourdomain.com
- Check existing docs and issues first

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Credited in documentation

Thank you for contributing! 🙏
