# [Radically Digital Wiki](https://wiki.radically.digital) - Infrastructure

---

Radically Digitals IaC for wiki.js - our internal knowledge base.

## Requires

- [asdf vm](https://asdf-vm.com)

## Install required dependencies

Required dependencies are found in `.tool-versions` and read by asdf.

```bash
### FIRST RUN
# Add required gcloud components
sh ./scripts/setup-gcp-cloud-components.sh
# Add system dependencies
asdf plugin add gcloud https://github.com/jthegedus/asdf-gcloud
asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git
asdf plugin add terragrunt https://github.com/ohmer/asdf-terragrunt.git

#  Install as needed based on .tool-versions
asdf install

# Copy the .env.example file and fill out the values in the .env
cp .env.example .env

# Login to GCP
gcloud auth login --no-launch-browser

# Login to GCP SDK
gcloud auth application-default login --no-launch-browser

### END FIRST RUN

# Setup local shell
. ./scripts/export-env.sh

# To Apply/Plan all
cd <environment>

# Init/Plan/Apply
# Note first apply may fail due to API's being enabled
terragrunt [init|plan|apply]
```

## Upload latest wikijs image

```bash
sh ./scripts/image-exchange.sh
```

<!-- MARKDOWN REFERENCES -->

[asdf vm]: https://asdf-vm.com/
