# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the project structure, technologies, and development conventions.

## Project Overview

This project is a full-stack, decentralized application for tokenizing Real-World Assets (RWAs). It implements a sovereign rollup on top of a modular blockchain stack.

The key components are:

*   **Frontend:** A React application built with TypeScript and Vite. It uses `wagmi` for wallet connectivity and `viem` for interacting with smart contracts. The frontend provides an interface for users to connect their wallets, deposit crypto to purchase RWA tokens, and register legal documents on the Data Availability (DA) layer.

*   **Backend (Rollup Stack):**
    *   **Sequencer:** A custom-built sequencer called **EV-Node**, which is part of the Evolve project. It is responsible for ordering and batching transactions.
    *   **Execution Layer:** **Reth**, a high-performance Ethereum execution client.
    *   **Data Availability (DA) Layer:** **Celestia**, a modular data availability network.

*   **Smart Contracts:** The project includes Solidity smart contracts for the RWA vault and document registry. These are located in the `rwa-soberano-evolve/src` directory.

*   **Orchestration:** The entire stack is orchestrated using **Docker Compose** and **Tilt**. This allows for a streamlined development experience.

## Building and Running

The project is designed to be run in a containerized environment using Docker and Tilt.

**Key Commands:**

*   **Start the entire stack:**
    ```bash
    tilt up
    ```
    This command will start all the services defined in the `docker-compose.*.yml` files and the `Tiltfile`.

*   **Stop the stack:**
    ```bash
    tilt down
    ```

*   **Load Testing:** The project includes a load testing tool called `spamoor`.
    ```bash
    cd spamoor
    make
    ./spamoor/bin/spamoor-daemon -h "http://localhost:8545" -p "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" --port 26678
    ```

**Services and Endpoints:**

*   **Reth (Execution Layer):** `http://localhost:8545`
*   **Celestia (Data Availability):** `http://localhost:26658`
*   **EV-Node (Sequencer):** `http://localhost:7331`
*   **Blockscout (Explorer):** `http://localhost:80`
*   **Tilt Dashboard:** `http://localhost:10350`

## Development Conventions

*   **Frontend:**
    *   The frontend code is located in the `frontend` directory.
    *   It is a standard React/Vite project.
    *   Dependencies are managed with `npm` and defined in `package.json`.
    *   Smart contract ABIs are located in `frontend/src/abis`.
    *   The main application component is `frontend/src/components/RWAInterface.tsx`.

*   **Smart Contracts:**
    *   The Solidity smart contracts are in the `rwa-soberano-evolve/src` directory.
    *   Tests for the smart contracts are in `rwa-soberano-evolve/test`.
    *   Deployment scripts are in `rwa-soberano-evolve/script`.

*   **Configuration:**
    *   The `rollup-init.sh` script is responsible for initializing the entire stack, including generating the `rollkit.env` file which contains the configuration for the EV-Node sequencer.
    *   The `rollkit-start.sh` script is the entrypoint for the EV-Node sequencer container. It reads the configuration from `rollkit.env` and starts the sequencer.
