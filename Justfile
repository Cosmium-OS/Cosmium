iso:
    @just iso-desktop

iso-desktop:
    #!/bin/sh
    bluebuild generate-iso -R podman --iso-name cosmium.iso image ghcr.io/cosmium-os/cosmium

iso-desktop-testing:
    #!/bin/sh
    bluebuild generate-iso -R podman --iso-name cosmium-testing.iso image ghcr.io/cosmium-os/cosmium:testing

iso-deck:
    #!/bin/sh
    bluebuild generate-iso -R podman --iso-name cosmium-deck.iso image ghcr.io/cosmium-os/cosmium-deck

iso-deck-testing:
    #!/bin/sh
    bluebuild generate-iso -R podman --iso-name cosmium-deck-testing.iso image ghcr.io/cosmium-os/cosmium-deck:testing
