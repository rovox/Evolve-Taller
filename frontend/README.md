# Frontend Application

This directory contains the frontend application for the Evolve Taller project. It is a React application built with Vite that interacts with the RWA (Real World Asset) smart contracts deployed on the local rollup.

## Features

-   Connect to a wallet (e.g., MetaMask).
-   View the status of the rollup and the deployed contracts.
-   Interact with the RWA contracts to create and manage assets.

## Getting Started

The frontend is automatically started when you run `tilt up` in the root of the project.

You can also run the frontend in standalone mode:

1.  **Install Dependencies**:
    ```bash
    npm install
    ```

2.  **Run Development Server**:
    ```bash
    npm run dev
    ```

The application will be available at [http://localhost:5173](http://localhost:5173).

## Configuration

The frontend is configured to connect to the local rollup by default. The contract addresses are automatically synced from the `rwa-soberano-evolve` directory when you run `tilt up`. The configuration can be found in `src/config/wagmi.ts`.