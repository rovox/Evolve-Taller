import React, { useState, useMemo } from 'react';
import { useAccount, useConnect, useDisconnect, useChainId, useWriteContract, useReadContract, usePublicClient } from 'wagmi';
import { parseEther, formatEther, keccak256, toHex } from 'viem';
import { metaMask } from 'wagmi/connectors';
import toast from 'react-hot-toast';
import { Wallet, FileText, ExternalLink, PlusCircle, ShoppingCart } from 'lucide-react';

import { RWASovereignRollupABI } from '../abis';

// Dirección del contrato unificado. Asegúrate de que esta sea la dirección correcta después de desplegar.
const RWA_CONTRACT_ADDRESS = import.meta.env.VITE_RWA_SOVEREIGN_ROLLUP_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3';

// URL del explorador de bloques para la red de Evolve. Ajústala si es necesario.
const BLOCK_EXPLORER_URL = 'http://localhost:4000';

const RWAInterface: React.FC = () => {
  const { address, isConnected } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const publicClient = usePublicClient()!;

  const [purchaseAmount, setPurchaseAmount] = useState('0.01');
  const [documentContent, setDocumentContent] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [loadingAction, setLoadingAction] = useState<'create' | 'purchase' | null>(null);

  const { writeContractAsync } = useWriteContract();

  // --- Lecturas del Contrato ---
  const { data: totalAssets, refetch: refetchTotalAssets } = useReadContract({
    address: RWA_CONTRACT_ADDRESS as `0x${string}`,
    abi: RWASovereignRollupABI.abi,
    functionName: 'totalAssets',
  });

  const { data: documentRecord, refetch: refetchDocumentRecord } = useReadContract({
    address: RWA_CONTRACT_ADDRESS as `0x${string}`,
    abi: RWASovereignRollupABI.abi,
    functionName: 'getDocumentRecord',
  });

  const { data: userBalance, refetch: refetchUserBalance } = useReadContract({
    address: RWA_CONTRACT_ADDRESS as `0x${string}`,
    abi: RWASovereignRollupABI.abi,
    functionName: 'balanceOf',
    args: [address!],
    query: { enabled: !!address },
  });

  const documentHash = useMemo(() => {
    if (documentRecord && Array.isArray(documentRecord) && documentRecord.length > 0) {
      return documentRecord[0] as `0x${string}`;
    }
    return null;
  }, [documentRecord]);

  // --- Handlers de Conexión ---
  const handleConnect = async () => {
    try {
      await connect({ connector: metaMask() });
      toast.success('Wallet conectada exitosamente!');
    } catch {
      toast.error('Error conectando la wallet. Asegúrate de tener MetaMask instalado.');
    }
  };

  // --- Handlers de Transacciones ---
  const handleCreateAsset = async () => {
    if (!documentContent.trim()) {
      toast.error('El contenido del documento no puede estar vacío.');
      return;
    }

    setIsLoading(true);
    setLoadingAction('create');
    try {
      const calculatedDocumentHash = keccak256(toHex(documentContent));

      const txHash = await writeContractAsync({
        address: RWA_CONTRACT_ADDRESS as `0x${string}`,
        abi: RWASovereignRollupABI.abi,
        functionName: 'createAsset',
        args: [calculatedDocumentHash],
      });

      toast.loading('Esperando confirmación de la transacción...', { id: 'tx-creation' });

      const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });

      if (receipt.status === 'success') {
        toast.success('¡Transacción confirmada!', { id: 'tx-creation' });
      } else {
        toast.error('La transacción falló.', { id: 'tx-creation' });
      }

      // Refrescar los datos después de la confirmación
      refetchDocumentRecord();

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Ocurrió un error desconocido.';
      toast.error(`Error al crear el activo: ${errorMessage}`);
    } finally {
      setIsLoading(false);
      setLoadingAction(null);
    }
  };

  const handlePurchaseFraction = async () => {
    if (!purchaseAmount || parseFloat(purchaseAmount) <= 0) {
      toast.error('Ingresa un monto válido para comprar.');
      return;
    }

    setIsLoading(true);
    setLoadingAction('purchase');
    try {
      const amountWei = parseEther(purchaseAmount);
      const txHash = await writeContractAsync({
        address: RWA_CONTRACT_ADDRESS as `0x${string}`,
        abi: RWASovereignRollupABI.abi,
        functionName: 'purchaseFraction',
        value: amountWei,
      });

      toast.loading('Esperando confirmación de la transacción...', { id: 'tx-purchase' });

      const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });

      if (receipt.status === 'success') {
        toast.success('¡Transacción confirmada!', { id: 'tx-purchase' });
      } else {
        toast.error('La transacción falló.', { id: 'tx-purchase' });
      }

      // Refrescar los datos después de la confirmación
      refetchTotalAssets();
      refetchUserBalance();

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Ocurrió un error desconocido.';
      toast.error(`Error al comprar la fracción: ${errorMessage}`);
    } finally {
      setIsLoading(false);
      setLoadingAction(null);
    }
  };

  // --- Renderizado ---

  if (!isConnected) {
    return (
      <div className="container">
        <div className="glass-card text-center" style={{ maxWidth: '400px', margin: '100px auto' }}>
          <div className="connect-wallet-icon">
            <Wallet size={32} color="white" />
          </div>
          <h2 className="text-title">Conectar a Evolve Rollup</h2>
          <p className="text-subtitle">Conecta tu wallet para tokenizar y fraccionalizar Activos del Mundo Real.</p>
          <button onClick={handleConnect} className="btn-primary">
            Conectar Wallet
          </button>
          <p className="text-label mt-4">Asegúrate de estar en la red Evolve (ID: 31337)</p>
        </div>
      </div>
    );
  }

  return (
    <div className="container">
      <div style={{ maxWidth: '1000px', margin: '0 auto' }}>
        <div className="glass-card mb-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-title">Panel de Control RWA Soberano</h1>
              <p className="text-subtitle">Tokenización y fraccionalización de activos en Evolve y Celestia</p>
            </div>
            <div style={{ textAlign: 'right' }}>
              <p className="text-label">Conectado como:</p>
              <p className="text-hash">{address?.slice(0, 8)}...{address?.slice(-6)}</p>
              <button onClick={() => disconnect()} className="btn-disconnect">
                Desconectar
              </button>
            </div>
          </div>
        </div>

        <div className="grid-3">
          {/* Panel de Estadísticas del Activo */}
          <div className="glass-card grid-span-2">
            <div className="flex items-center gap-4 mb-4">
              <FileText color="#00bfff" size={24} />
              <h3 className="card-title">Estado del Activo Tokenizado</h3>
            </div>
            <div className="info-grid">
              <div>
                <p className="text-label">Valor Total Invertido</p>
                <p className="text-value">{totalAssets ? `${parseFloat(formatEther(totalAssets as bigint)).toFixed(4)} ETH` : '0.0000 ETH'}</p>
              </div>
              <div>
                <p className="text-label">Mis Acciones (Shares)</p>
                <p className="text-value">{userBalance ? `${parseFloat(formatEther(userBalance as bigint)).toFixed(4)} RWAS` : '0.0000 RWAS'}</p>
              </div>
            </div>
            <div className="document-hash-container">
              <h4 className="text-label">Hash del Documento Legal (en Celestia DA)</h4>
              <div className="text-hash">
                {documentHash ? (
                  <a href={`${BLOCK_EXPLORER_URL}/tx/${documentHash}`} target="_blank" rel="noopener noreferrer" className="link">
                    {`${documentHash.slice(0, 20)}...${documentHash.slice(-20)}`}
                  </a>
                ) : 'Aún no registrado'}
              </div>
            </div>
            <button onClick={() => { refetchTotalAssets(); refetchDocumentRecord(); refetchUserBalance(); }} className="btn-secondary mt-4">
              <ExternalLink size={14} /> Actualizar Datos
            </button>
          </div>

          {/* Panel de Crear Activo */}
          <div className="glass-card">
            <div className="flex items-center gap-3 mb-4">
              <PlusCircle color="#34D399" size={22} />
              <h3 className="card-title">1. Crear Activo RWA</h3>
            </div>
            <p className="text-label mb-2">Contenido del documento para generar el hash:</p>
            <textarea
              value={documentContent}
              onChange={(e) => setDocumentContent(e.target.value)}
              className="textarea-field"
              placeholder="Ej: Contrato de propiedad del inmueble X..."
              rows={4}
            />
            <button onClick={handleCreateAsset} disabled={isLoading} className="btn-primary w-full mt-4">
              {loadingAction === 'create' ? (
                <><div className="loading-spinner"></div> Creando Activo...</>
              ) : 'Crear y Registrar Activo'}
            </button>
            <p className="text-label-sm mt-2">Esta acción registra el hash del documento en la blockchain. Solo el admin puede hacerlo.</p>
          </div>

          {/* Panel de Comprar Fracción */}
          <div className="glass-card grid-span-3">
            <div className="flex items-center gap-3 mb-4">
              <ShoppingCart color="#A78BFA" size={22} />
              <h3 className="card-title">2. Comprar Fracciones del Activo</h3>
            </div>
            <div className="flex items-end gap-4">
              <div className="flex-grow">
                <label className="text-label">Cantidad a Invertir (ETH)</label>
                <input
                  type="number"
                  value={purchaseAmount}
                  onChange={(e) => setPurchaseAmount(e.target.value)}
                  step="0.01"
                  min="0.001"
                  className="input-field"
                  placeholder="0.1"
                />
              </div>
              <button onClick={handlePurchaseFraction} disabled={isLoading} className="btn-primary" style={{ height: '44px' }}>
                {loadingAction === 'purchase' ? (
                  <><div className="loading-spinner"></div> Procesando...</>
                ) : 'Comprar Fracción'}
              </button>
            </div>
            <p className="text-label-sm mt-2">Recibirás tokens (RWAS) que representan tu participación en el activo.</p>
          </div>
        </div>

        <div className="glass-card text-center mt-6">
          <p className="text-label">Red Conectada: {chainId === 31337 ? 'Evolve Local' : `ID Desconocido: ${chainId}`}</p>
        </div>
      </div>
    </div>
  );
};

export default RWAInterface;
