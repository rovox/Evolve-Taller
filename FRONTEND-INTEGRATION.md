# 🎨 Guía de Integración Frontend - Sistema RWA ERC1155

## ⚙️ Nota sobre scripts y Tilt

Este repo ahora centraliza los helpers operativos en la carpeta `./scripts/`.

- `./scripts/deploy-rwa-contracts.sh` : despliega los contratos (usa `forge` o el helper Node si existe).
- `./scripts/run-contract-tests.sh` : ejecuta `forge test -vv` en `rwa-soberano-evolve`.
- `./scripts/test-rwa-integration.sh` : prueba de humo E2E (ya existente).
- `./scripts/sync-contract-addresses.sh` : copia `deployed-addresses.env` a `frontend/public` y genera `.env.local`.
- `./scripts/start-frontend.sh` : prepara y arranca `npm run dev` (Vite).
- `./scripts/ci-integration.sh` : wrapper que orquesta deploy → tests → integration → sync → (opcional) frontend.

El `Tiltfile` fue actualizado para utilizar estos scripts (ej: `./scripts/deploy-rwa-contracts.sh`, `./scripts/run-contract-tests.sh`, `./scripts/sync-contract-addresses.sh`, `./scripts/start-frontend.sh`). Esto mantiene la lógica de orquestación en Tilt pero agrupa la lógica operativa en scripts bash versionables y fáciles de ejecutar manualmente o desde CI.

Comandos útiles fuera de Tilt:

```bash
# Ejecutar todo (deploy -> tests -> integration -> sync), sin iniciar frontend:
./scripts/ci-integration.sh

# Ejecutar y además iniciar frontend en primer plano:
./scripts/ci-integration.sh --start-frontend

# Arrancar solo el frontend rápido (dev server):
./scripts/start-frontend.sh
```

## 📋 Setup Inicial

### 1. Instalar Dependencias

```bash
cd frontend
npm install ethers@^5.7.0 wagmi viem
```

### 2. Copiar ABIs

Los ABIs se generan automáticamente después de compilar los contratos con `forge build`. Los scripts auxiliares en `scripts/` y `rwa-soberano-evolve/script/` se encargan de copiar los ABIs necesarios al directorio `frontend/src/abis/`.

Por ejemplo, el script `deploy-rwa-contracts.sh` ya incluye la lógica para copiar los ABIs relevantes. Asegúrate de que `frontend/src/abis/index.ts` importe los nombres de archivo correctos si los nombres de los contratos cambian.

### 3. Configurar Direcciones

Crear `frontend/src/config/contracts.ts`:

```typescript
export const contracts = {
  rwaToken: {
    address: "0x...", // desde deployed-addresses-erc1155.env
    abi: RWATokenABI,
  },
  dividendDistributor: {
    address: "0x...",
    abi: DividendDistributorABI,
  },
  documentRegistry: {
    address: "0x...",
    abi: DocumentRegistryABI,
  },
};
```

---

## 🔌 Hooks de React

### Hook: useRWAToken

```typescript
// src/hooks/useRWAToken.ts
import { useContract, useSigner } from 'wagmi';
import RWATokenABI from '../abis/RWAToken.json';

export function useRWAToken() {
  const { data: signer } = useSigner();
  
  const contract = useContract({
    address: contracts.rwaToken.address,
    abi: RWATokenABI.abi,
    signerOrProvider: signer,
  });

  // Crear activo
  const createAsset = async (
    name: string,
    description: string,
    assetType: string,
    totalShares: number,
    valueInUSD: number,
    ipfsMetadata: string
  ) => {
    const tx = await contract.createAsset(
      name,
      description,
      assetType,
      totalShares,
      valueInUSD,
      ipfsMetadata
    );
    await tx.wait();
    return tx;
  };

  // Mintear shares
  const mintShares = async (
    to: string,
    assetId: number,
    amount: string
  ) => {
    const tx = await contract.mintShares(
      to,
      assetId,
      ethers.utils.parseUnits(amount, 18),
      "0x"
    );
    await tx.wait();
    return tx;
  };

  // Obtener info del activo
  const getAssetInfo = async (assetId: number) => {
    return await contract.getAssetInfo(assetId);
  };

  // Obtener accionistas
  const getShareholders = async (assetId: number) => {
    return await contract.getShareholders(assetId);
  };

  // Obtener porcentaje
  const getSharePercentage = async (assetId: number, address: string) => {
    const percentage = await contract.getSharePercentageFormatted(assetId, address);
    return percentage.toNumber();
  };

  return {
    contract,
    createAsset,
    mintShares,
    getAssetInfo,
    getShareholders,
    getSharePercentage,
  };
}
```

### Hook: useDividends

```typescript
// src/hooks/useDividends.ts
import { useContract, useSigner } from 'wagmi';
import DividendDistributorABI from '../abis/DividendDistributor.json';

export function useDividends() {
  const { data: signer } = useSigner();
  
  const contract = useContract({
    address: contracts.dividendDistributor.address,
    abi: DividendDistributorABI.abi,
    signerOrProvider: signer,
  });

  // Crear dividendo
  const createDividend = async (
    assetId: number,
    description: string,
    amountInEth: string
  ) => {
    const tx = await contract.createDividend(
      assetId,
      description,
      { value: ethers.utils.parseEther(amountInEth) }
    );
    await tx.wait();
    return tx;
  };

  // Reclamar dividendo
  const claimDividend = async (assetId: number, dividendIndex: number) => {
    const tx = await contract.claimDividend(assetId, dividendIndex);
    await tx.wait();
    return tx;
  };

  // Obtener dividendos disponibles
  const getAvailableDividends = async (assetId: number, address: string) => {
    const [indices, amounts] = await contract.getAvailableDividends(
      assetId,
      address
    );
    
    return indices.map((index: any, i: number) => ({
      index: index.toNumber(),
      amount: ethers.utils.formatEther(amounts[i]),
    }));
  };

  return {
    contract,
    createDividend,
    claimDividend,
    getAvailableDividends,
  };
}
```

---

## 🎨 Componentes de UI

### Componente: CreateAssetForm

```tsx
// src/components/CreateAssetForm.tsx
import React, { useState } from 'react';
import { useRWAToken } from '../hooks/useRWAToken';

export function CreateAssetForm() {
  const { createAsset } = useRWAToken();
  const [loading, setLoading] = useState(false);
  
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    assetType: 'Departamento',
    totalShares: 1000,
    valueInUSD: 200000,
    ipfsMetadata: '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      await createAsset(
        formData.name,
        formData.description,
        formData.assetType,
        formData.totalShares,
        formData.valueInUSD,
        formData.ipfsMetadata
      );
      
      alert('Activo creado exitosamente!');
    } catch (error) {
      console.error(error);
      alert('Error al crear activo');
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium">Nombre</label>
        <input
          type="text"
          value={formData.name}
          onChange={(e) => setFormData({ ...formData, name: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium">Descripción</label>
        <textarea
          value={formData.description}
          onChange={(e) => setFormData({ ...formData, description: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium">Tipo de Activo</label>
        <select
          value={formData.assetType}
          onChange={(e) => setFormData({ ...formData, assetType: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300"
        >
          <option>Departamento</option>
          <option>Casa</option>
          <option>Obra de Arte</option>
          <option>Automóvil</option>
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium">Total Shares</label>
        <input
          type="number"
          value={formData.totalShares}
          onChange={(e) => setFormData({ ...formData, totalShares: parseInt(e.target.value) })}
          className="mt-1 block w-full rounded-md border-gray-300"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium">Valor en USD</label>
        <input
          type="number"
          value={formData.valueInUSD}
          onChange={(e) => setFormData({ ...formData, valueInUSD: parseInt(e.target.value) })}
          className="mt-1 block w-full rounded-md border-gray-300"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium">IPFS Metadata</label>
        <input
          type="text"
          value={formData.ipfsMetadata}
          onChange={(e) => setFormData({ ...formData, ipfsMetadata: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300"
          placeholder="QmHash..."
        />
      </div>

      <button
        type="submit"
        disabled={loading}
        className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 disabled:opacity-50"
      >
        {loading ? 'Creando...' : 'Crear Activo'}
      </button>
    </form>
  );
}
```

### Componente: AssetCard

```tsx
// src/components/AssetCard.tsx
import React, { useEffect, useState } from 'react';
import { useRWAToken } from '../hooks/useRWAToken';
import { useAccount } from 'wagmi';

interface AssetCardProps {
  assetId: number;
}

export function AssetCard({ assetId }: AssetCardProps) {
  const { getAssetInfo, getSharePercentage } = useRWAToken();
  const { address } = useAccount();
  
  const [assetInfo, setAssetInfo] = useState<any>(null);
  const [myPercentage, setMyPercentage] = useState(0);

  useEffect(() => {
    const loadData = async () => {
      const info = await getAssetInfo(assetId);
      setAssetInfo(info);
      
      if (address) {
        const percentage = await getSharePercentage(assetId, address);
        setMyPercentage(percentage);
      }
    };
    
    loadData();
  }, [assetId, address]);

  if (!assetInfo) return <div>Cargando...</div>;

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h3 className="text-xl font-bold mb-2">{assetInfo.name}</h3>
      <p className="text-gray-600 mb-4">{assetInfo.description}</p>
      
      <div className="grid grid-cols-2 gap-4">
        <div>
          <p className="text-sm text-gray-500">Tipo</p>
          <p className="font-semibold">{assetInfo.assetType}</p>
        </div>
        
        <div>
          <p className="text-sm text-gray-500">Valor USD</p>
          <p className="font-semibold">${assetInfo.valueInUSD.toLocaleString()}</p>
        </div>
        
        <div>
          <p className="text-sm text-gray-500">Total Shares</p>
          <p className="font-semibold">{assetInfo.totalShares.toString()}</p>
        </div>
        
        {myPercentage > 0 && (
          <div>
            <p className="text-sm text-gray-500">Mi Participación</p>
            <p className="font-semibold text-green-600">{myPercentage}%</p>
          </div>
        )}
      </div>
      
      {myPercentage > 0 && (
        <div className="mt-4 pt-4 border-t">
          <p className="text-sm text-gray-500">Valor de mi participación</p>
          <p className="text-2xl font-bold text-green-600">
            ${((assetInfo.valueInUSD * myPercentage) / 100).toLocaleString()}
          </p>
        </div>
      )}
    </div>
  );
}
```

### Componente: DividendsList

```tsx
// src/components/DividendsList.tsx
import React, { useEffect, useState } from 'react';
import { useDividends } from '../hooks/useDividends';
import { useAccount } from 'wagmi';

interface DividendsListProps {
  assetId: number;
}

export function DividendsList({ assetId }: DividendsListProps) {
  const { getAvailableDividends, claimDividend } = useDividends();
  const { address } = useAccount();
  
  const [dividends, setDividends] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const loadDividends = async () => {
      if (address) {
        const available = await getAvailableDividends(assetId, address);
        setDividends(available);
      }
    };
    
    loadDividends();
  }, [assetId, address]);

  const handleClaim = async (dividendIndex: number) => {
    setLoading(true);
    try {
      await claimDividend(assetId, dividendIndex);
      alert('Dividendo reclamado exitosamente!');
      
      // Recargar dividendos
      const available = await getAvailableDividends(assetId, address!);
      setDividends(available);
    } catch (error) {
      console.error(error);
      alert('Error al reclamar dividendo');
    } finally {
      setLoading(false);
    }
  };

  if (dividends.length === 0) {
    return (
      <div className="text-center py-8 text-gray-500">
        No hay dividendos disponibles
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <h3 className="text-lg font-bold">Dividendos Disponibles</h3>
      
      {dividends.map((dividend) => (
        <div key={dividend.index} className="bg-white rounded-lg shadow p-4 flex justify-between items-center">
          <div>
            <p className="font-semibold">Dividendo #{dividend.index}</p>
            <p className="text-2xl font-bold text-green-600">{dividend.amount} ETH</p>
          </div>
          
          <button
            onClick={() => handleClaim(dividend.index)}
            disabled={loading}
            className="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:opacity-50"
          >
            {loading ? 'Reclamando...' : 'Reclamar'}
          </button>
        </div>
      ))}
    </div>
  );
}
```

---

## 🔄 Escuchar Eventos

### Setup de Listeners

```typescript
// src/hooks/useRWAEvents.ts
import { useEffect } from 'react';
import { useContract } from 'wagmi';

export function useRWAEvents(onAssetCreated?: (assetId: number) => void) {
  const contract = useContract({
    address: contracts.rwaToken.address,
    abi: RWATokenABI.abi,
  });

  useEffect(() => {
    if (!contract) return;

    // Escuchar evento AssetCreated
    const filter = contract.filters.AssetCreated();
    
    contract.on(filter, (assetId, name, assetType, totalShares, valueInUSD, ipfsMetadata) => {
      console.log('Nuevo activo creado:', {
        assetId: assetId.toNumber(),
        name,
        assetType,
      });
      
      if (onAssetCreated) {
        onAssetCreated(assetId.toNumber());
      }
    });

    return () => {
      contract.removeAllListeners(filter);
    };
  }, [contract, onAssetCreated]);
}
```

---

## 📊 Dashboard Completo

### Componente Principal

```tsx
// src/pages/Dashboard.tsx
import React, { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { useRWAToken } from '../hooks/useRWAToken';
import { AssetCard } from '../components/AssetCard';
import { DividendsList } from '../components/DividendsList';
import { CreateAssetForm } from '../components/CreateAssetForm';

export function Dashboard() {
  const { address, isConnected } = useAccount();
  const { contract } = useRWAToken();
  
  const [assetIds, setAssetIds] = useState<number[]>([]);
  const [selectedAsset, setSelectedAsset] = useState<number | null>(null);

  useEffect(() => {
    const loadAssets = async () => {
      if (contract) {
        const counter = await contract.assetCounter();
        const ids = Array.from({ length: counter.toNumber() }, (_, i) => i);
        setAssetIds(ids);
      }
    };
    
    loadAssets();
  }, [contract]);

  if (!isConnected) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="text-center">
          <h2 className="text-2xl font-bold mb-4">Conecta tu Wallet</h2>
          <p className="text-gray-600">Para acceder al dashboard</p>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-3xl font-bold mb-8">Dashboard RWA</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Lista de Activos */}
        <div className="md:col-span-2">
          <h2 className="text-xl font-bold mb-4">Mis Activos</h2>
          <div className="grid gap-4">
            {assetIds.map((id) => (
              <div key={id} onClick={() => setSelectedAsset(id)}>
                <AssetCard assetId={id} />
              </div>
            ))}
          </div>
        </div>
        
        {/* Panel Lateral */}
        <div className="space-y-6">
          {selectedAsset !== null && (
            <>
              <h2 className="text-xl font-bold">Activo #{selectedAsset}</h2>
              <DividendsList assetId={selectedAsset} />
            </>
          )}
          
          <div className="bg-white rounded-lg shadow p-4">
            <h3 className="text-lg font-bold mb-4">Crear Nuevo Activo</h3>
            <CreateAssetForm />
          </div>
        </div>
      </div>
    </div>
  );
}
```

---

## 🎯 Testing en Frontend

### Setup de Testing

```typescript
// src/test/RWAToken.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import { Dashboard } from '../pages/Dashboard';
import { WagmiConfig } from 'wagmi';

describe('RWAToken Integration', () => {
  it('should display asset information', async () => {
    render(
      <WagmiConfig client={client}>
        <Dashboard />
      </WagmiConfig>
    );

    await waitFor(() => {
      expect(screen.getByText('Dashboard RWA')).toBeInTheDocument();
    });
  });
});
```

---

## 🔧 Variables de Entorno

```bash
# frontend/.env.local
VITE_RWA_TOKEN_ADDRESS=0x...
VITE_DIVIDEND_DISTRIBUTOR_ADDRESS=0x...
VITE_DOCUMENT_REGISTRY_ADDRESS=0x...
VITE_RPC_URL=http://localhost:8545
VITE_CHAIN_ID=31337
```

---

## 📚 Recursos Adicionales

- **Wagmi Docs**: https://wagmi.sh/
- **Ethers.js**: https://docs.ethers.org/
- **React Query**: https://tanstack.com/query/latest

---

**Estado**: ✅ LISTO PARA INTEGRACIÓN  
**Framework**: React + TypeScript + Wagmi  
**Última actualización**: Octubre 2025
