import React, { useState } from 'react'
import { useAccount, useConnect, useDisconnect, useChainId, useWriteContract, useReadContract } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { metaMask } from 'wagmi/connectors'
import toast from 'react-hot-toast'
import { Wallet, FileText, ExternalLink } from 'lucide-react'

// Importaciones de ABIs reales
import { DocumentRegistryABI, RWASovereignRollupABI } from '../abis'
//import DocumentRegistryABI from '../abis/DocumentRegistry.json';
//import RWASovereignRollupABI from '../abis/RWASovereignRollup.json';

// ABIs simuladas - REEMPLAZA con tus ABIs reales
/*const ASSET_REGISTRY_ABI = [
  "function registerDocument(bytes32 documentHash) external returns (bytes32)",
  "function getDocumentHash(uint256 rwaId) external view returns (bytes32)",
  "function getDocumentRecord(uint256 rwaId) external view returns (tuple(bytes32 documentHash, bytes32 daTransactionHash, uint256 timestamp, address registeredBy))",
  "function RWA_ID() external view returns (uint256)"
] as const

const RWA_VAULT_ABI = [
  "function deposit(uint256 assets, address receiver) external returns (uint256 shares)",
  "function totalAssets() external view returns (uint256)",
  "function balanceOf(address owner) external view returns (uint256)"
] as const*/

// Direcciones de contrato - ACTUALIZA con tus direcciones reales
const CONTRACT_ADDRESSES = {
  registry: import.meta.env.VITE_REGISTRY_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  vault: import.meta.env.VITE_VAULT_ADDRESS || '0xe7f1725E7734CE288F8367e1Bb143E90bb3F5382'
}

const RWAInterface: React.FC = () => {
  const { address, isConnected } = useAccount()
  const { connect } = useConnect()
  const { disconnect } = useDisconnect()
  const chainId = useChainId()
  
  const [depositAmount, setDepositAmount] = useState('0.1')
  const [documentContent, setDocumentContent] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  // Lectura del total de activos
  const { data: totalAssets, refetch: refetchAssets } = useReadContract({
    address: CONTRACT_ADDRESSES.vault,
    abi: DocumentRegistryABI.abi, // Usa el ABI importado
    functionName: 'totalAssets',
  }) as { data: bigint | undefined; refetch: () => void }

  // Lectura del hash del documento
  const { data: documentHash, refetch: refetchDocument } = useReadContract({
    address: CONTRACT_ADDRESSES.registry,
    abi: RWASovereignRollupABI.abi, // Usa el ABI importado
    functionName: 'getDocumentHash',
    args: [1n], // RWA_ID = 1
  }) as { data: bigint | undefined; refetch: () => void }

  const { writeContractAsync } = useWriteContract()

  const handleConnect = async () => {
    try {
      await connect({ connector: metaMask() })
      toast.success('Wallet conectada exitosamente!')
    } catch {
      toast.error('Error conectando wallet')
    }
  }

  const handleDeposit = async () => {
    if (!isConnected || !depositAmount) {
      toast.error('Conecta tu wallet e ingresa un monto')
      return
    }

    setIsLoading(true)
    try {
      const amountWei = parseEther(depositAmount)
      const tx = await writeContractAsync({
        address: CONTRACT_ADDRESSES.vault,
        abi: RWASovereignRollupABI.abi,
        functionName: 'deposit',
        args: [amountWei, address!],
      })
      
      toast.success(`Depósito de ${depositAmount} ETH exitoso!`)
      console.log('Transaction hash:', tx)
      
      // Refrescar datos
      setTimeout(() => {
        refetchAssets()
      }, 2000)
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Error desconocido'
      toast.error(`Error: ${errorMessage}`)
    } finally {
      setIsLoading(false)
    }
  }

  const handleRegisterDocument = async () => {
    if (!documentContent.trim()) {
      toast.error('Ingresa contenido para el documento')
      return
    }

    setIsLoading(true)
    try {
      // En un caso real, calcularías el hash del documento
      const documentHash = `0x${Buffer.from(documentContent).toString('hex')}`
      
      const tx = await writeContractAsync({
        address: CONTRACT_ADDRESSES.registry,
        abi: DocumentRegistryABI.abi, // ← CAMBIADO
        functionName: 'registerDocument',
        args: [documentHash as `0x${string}`],
      })
      
      toast.success('Documento registrado exitosamente!')
      console.log('Document TX:', tx)
      
      setTimeout(() => {
        refetchDocument()
      }, 2000)
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Error desconocido'
      toast.error(`Error: ${errorMessage}`)
    } finally {
      setIsLoading(false)
    }
  }

  if (!isConnected) {
    return (
      <div className="container">
        <div className="glass-card text-center" style={{ maxWidth: '400px', margin: '100px auto' }}>
          <div style={{ 
            width: '64px', 
            height: '64px', 
            background: 'linear-gradient(135deg, #00bfff 0%, #0080ff 100%)',
            borderRadius: '50%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 24px'
          }}>
            <Wallet size={32} color="white" />
          </div>
          <h2 className="text-title" style={{ fontSize: '1.75rem' }}>Conectar a Evolve Rollup</h2>
          <p className="text-subtitle" style={{ marginBottom: '32px' }}>
            Conecta tu wallet para interactuar con el RWA Tokenizado
          </p>
          <button onClick={handleConnect} className="btn-primary">
            Conectar Wallet
          </button>
          <p className="text-label mt-4">
            Asegúrate de estar en la red Evolve (ID: 31337)
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="container">
      <div style={{ maxWidth: '1000px', margin: '0 auto' }}>
        {/* Header */}
        <div className="glass-card mb-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-title">RWA Soberano Evolve</h1>
              <p className="text-subtitle">Tokenización de Activos del Mundo Real en Celestia</p>
            </div>
            <div style={{ textAlign: 'right' }}>
              <p className="text-label">Conectado como</p>
              <p style={{ 
                fontFamily: 'Monaco, Menlo, monospace',
                color: 'white',
                fontSize: '0.9rem'
              }}>
                {address?.slice(0, 8)}...{address?.slice(-6)}
              </p>
              <button
                onClick={() => disconnect()}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#ff6b6b',
                  cursor: 'pointer',
                  fontSize: '0.8rem',
                  marginTop: '4px'
                }}
              >
                Desconectar
              </button>
            </div>
          </div>
        </div>

        <div className="grid-2">
          {/* Panel de Estadísticas */}
          <div className="glass-card">
            <div className="flex items-center gap-4 mb-4">
              <FileText color="#00bfff" size={24} />
              <h3 style={{ fontSize: '1.25rem', fontWeight: '600', color: 'white', margin: 0 }}>
                Valor Total del RWA
              </h3>
            </div>
            <p className="text-value">
              {totalAssets ? parseFloat(formatEther(totalAssets)).toFixed(4) : '0.0000'} ETH
            </p>
            <p className="text-label">Valor total bajo gestión</p>
            
            <div style={{ 
              marginTop: '24px', 
              padding: '16px',
              background: 'rgba(0, 191, 255, 0.1)',
              borderRadius: '8px',
              border: '1px solid rgba(0, 191, 255, 0.2)'
            }}>
              <h4 style={{ color: 'white', fontSize: '0.9rem', fontWeight: '600', margin: '0 0 8px 0' }}>
                Hash del Documento Legal
              </h4>
              <div className="text-hash">
                {documentHash ?
                    `0x${documentHash.toString(16).padStart(64, '0').slice(0, 20)}...${documentHash.toString(16).padStart(64, '0').slice(-20)}` :
                    'No registrado'
                }
              </div>
              <button
                onClick={() => refetchDocument()}
                className="btn-secondary"
                style={{ fontSize: '0.8rem', padding: '6px 12px' }}
              >
                <ExternalLink size={14} style={{ marginRight: '4px' }} />
                Actualizar Hash
              </button>
            </div>
          </div>

          {/* Panel de Depósito */}
          <div className="glass-card">
            <h3 style={{ fontSize: '1.25rem', fontWeight: '600', color: 'white', margin: '0 0 20px 0' }}>
              Comprar Fracción del RWA
            </h3>
            <div style={{ marginBottom: '16px' }}>
              <label className="text-label">Cantidad a Invertir (ETH)</label>
              <input
                type="number"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                step="0.001"
                min="0.001"
                className="input-field"
                placeholder="0.1"
              />
            </div>
            <button
              onClick={handleDeposit}
              disabled={isLoading}
              className="btn-primary"
              style={{ background: 'linear-gradient(135deg, #00cc88 0%, #00b377 100%)' }}
            >
              {isLoading ? (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                  <div className="loading-spinner"></div>
                  Procesando...
                </div>
              ) : (
                `Comprar ${depositAmount} ETH de Fracción`
              )}
            </button>
            <p className="text-label mt-4">
              Recibirás tokens de participación proporcionales en el vault del RWA
            </p>
          </div>

          {/* Panel de Registro de Documentos */}
          <div className="glass-card grid-full">
            <h3 style={{ fontSize: '1.25rem', fontWeight: '600', color: 'white', margin: '0 0 20px 0' }}>
              <FileText size={20} style={{ marginRight: '8px' }} />
              Registro de Documento Legal en Celestia DA
            </h3>
            <div style={{ marginBottom: '16px' }}>
              <label className="text-label">Contenido del Documento Legal</label>
              <textarea
                value={documentContent}
                onChange={(e) => setDocumentContent(e.target.value)}
                className="textarea-field"
                placeholder="Ingresa el contenido del documento legal del RWA (escritura, contrato, etc.)..."
                rows={4}
              />
            </div>
            <button
              onClick={handleRegisterDocument}
              disabled={isLoading}
              className="btn-primary"
            >
              {isLoading ? (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                  <div className="loading-spinner"></div>
                  Registrando en Celestia DA...
                </div>
              ) : (
                'Registrar Documento en Celestia DA'
              )}
            </button>
            <p className="text-label mt-4">
              El hash del documento será registrado de forma inmutable en el rollup de Evolve 
              y garantizado por la capa de disponibilidad de datos de Celestia
            </p>
          </div>
        </div>

        {/* Información de Red */}
        <div className="glass-card text-center mt-6">
          <p className="text-label">
            Red: {chainId === 31337 ? 'Evolve Local' : chainId === 200101 ? 'Celestia Mocha' : `ID: ${chainId}`}
          </p>
        </div>
      </div>
    </div>
  )
}

export default RWAInterface