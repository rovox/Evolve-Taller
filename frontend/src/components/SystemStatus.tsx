import React, { useState, useEffect } from 'react'
import { Activity, Check, X, Loader2, Database, Box, FileText } from 'lucide-react'

interface ContractStatus {
  address: string
  deployed: boolean
  loading: boolean
  blockNumber?: number
}

interface SystemStatusProps {
  rpcUrl?: string
}

const SystemStatus: React.FC<SystemStatusProps> = ({ rpcUrl = 'http://localhost:8545' }) => {
  const [contracts, setContracts] = useState<{
    registry: ContractStatus
    token: ContractStatus
    rwa: ContractStatus
  }>({
    registry: { address: '', deployed: false, loading: true },
    token: { address: '', deployed: false, loading: true },
    rwa: { address: '', deployed: false, loading: true },
  })
  
  const [blockNumber, setBlockNumber] = useState<number>(0)
  const [rpcConnected, setRpcConnected] = useState(false)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    // Load deployed addresses
    const loadAddresses = async () => {
      try {
        const response = await fetch('/deployed-addresses.env')
        const text = await response.text()
        const lines = text.split('\n')
        const addresses: Record<string, string> = {}
        
        lines.forEach(line => {
          const [key, value] = line.split('=')
          if (key && value) {
            addresses[key.trim()] = value.trim()
          }
        })

        return {
          registry: addresses.REGISTRY_ADDRESS || '',
          token: addresses.TOKEN_ADDRESS || '',
          rwa: addresses.RWA_ADDRESS || '',
        }
      } catch {
        // Fallback to environment variables
        return {
          registry: import.meta.env.VITE_REGISTRY_ADDRESS || '',
          token: import.meta.env.VITE_TOKEN_ADDRESS || '',
          rwa: import.meta.env.VITE_RWA_ADDRESS || '',
        }
      }
    }

    const checkRPC = async () => {
      try {
        const response = await fetch(rpcUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            jsonrpc: '2.0',
            method: 'eth_blockNumber',
            params: [],
            id: 1
          })
        })
        const data = await response.json()
        if (data.result) {
          setBlockNumber(parseInt(data.result, 16))
          setRpcConnected(true)
          return true
        }
        return false
      } catch {
        setRpcConnected(false)
        return false
      }
    }

    const checkContract = async (address: string): Promise<boolean> => {
      if (!address || address === '0x0000000000000000000000000000000000000000') {
        return false
      }
      
      try {
        const response = await fetch(rpcUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            jsonrpc: '2.0',
            method: 'eth_getCode',
            params: [address, 'latest'],
            id: 1
          })
        })
        const data = await response.json()
        return data.result && data.result !== '0x'
      } catch {
        return false
      }
    }

    const verifySystem = async () => {
      setIsLoading(true)
      
      const addresses = await loadAddresses()
      const rpcOk = await checkRPC()

      if (rpcOk) {
        const [registryDeployed, tokenDeployed, rwaDeployed] = await Promise.all([
          checkContract(addresses.registry),
          checkContract(addresses.token),
          checkContract(addresses.rwa),
        ])

        setContracts({
          registry: { 
            address: addresses.registry, 
            deployed: registryDeployed, 
            loading: false 
          },
          token: { 
            address: addresses.token, 
            deployed: tokenDeployed, 
            loading: false 
          },
          rwa: { 
            address: addresses.rwa, 
            deployed: rwaDeployed, 
            loading: false 
          },
        })
      }

      setIsLoading(false)
    }

    verifySystem()
    
    // Poll for block updates
    const interval = setInterval(checkRPC, 5000)
    return () => clearInterval(interval)
  }, [rpcUrl])

  const StatusIcon: React.FC<{ deployed: boolean; loading: boolean }> = ({ deployed, loading }) => {
    if (loading) return <Loader2 className="animate-spin" size={20} color="#00bfff" />
    return deployed ? <Check size={20} color="#00ff88" /> : <X size={20} color="#ff4444" />
  }

  const allDeployed = contracts.registry.deployed && contracts.token.deployed && contracts.rwa.deployed
  const allLoaded = !contracts.registry.loading && !contracts.token.loading && !contracts.rwa.loading

  return (
    <div style={{
      background: 'rgba(0, 191, 255, 0.05)',
      backdropFilter: 'blur(10px)',
      border: '1px solid rgba(0, 191, 255, 0.2)',
      borderRadius: '16px',
      padding: '24px',
      marginBottom: '24px',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '20px' }}>
        <Activity size={28} color="#00bfff" />
        <h2 style={{ margin: 0, fontSize: '1.5rem', color: 'white' }}>
          System Status
        </h2>
        {allDeployed && allLoaded && (
          <span style={{
            marginLeft: 'auto',
            padding: '6px 12px',
            background: 'rgba(0, 255, 136, 0.2)',
            border: '1px solid rgba(0, 255, 136, 0.4)',
            borderRadius: '8px',
            color: '#00ff88',
            fontSize: '0.875rem',
            fontWeight: '600',
          }}>
            ✓ All Systems Operational
          </span>
        )}
      </div>

      {/* RPC Status */}
      <div style={{
        display: 'grid',
        gap: '12px',
        marginBottom: '20px',
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '12px',
          padding: '12px',
          background: rpcConnected ? 'rgba(0, 255, 136, 0.1)' : 'rgba(255, 68, 68, 0.1)',
          border: `1px solid ${rpcConnected ? 'rgba(0, 255, 136, 0.3)' : 'rgba(255, 68, 68, 0.3)'}`,
          borderRadius: '8px',
        }}>
          {rpcConnected ? <Check size={20} color="#00ff88" /> : <X size={20} color="#ff4444" />}
          <Database size={20} color={rpcConnected ? '#00ff88' : '#ff4444'} />
          <div style={{ flex: 1 }}>
            <div style={{ color: 'white', fontWeight: '600' }}>RPC Connection</div>
            <div style={{ color: 'rgba(255, 255, 255, 0.6)', fontSize: '0.875rem' }}>
              {rpcUrl} {rpcConnected && `• Block #${blockNumber}`}
            </div>
          </div>
        </div>
      </div>

      {/* Contracts Status */}
      <div style={{
        display: 'grid',
        gap: '12px',
      }}>
        <ContractCard
          name="DocumentRegistry"
          icon={<FileText size={20} />}
          address={contracts.registry.address}
          deployed={contracts.registry.deployed}
          loading={contracts.registry.loading}
        />
        <ContractCard
          name="AssetToken (ERC721)"
          icon={<Box size={20} />}
          address={contracts.token.address}
          deployed={contracts.token.deployed}
          loading={contracts.token.loading}
        />
        <ContractCard
          name="RWASovereignRollup"
          icon={<Activity size={20} />}
          address={contracts.rwa.address}
          deployed={contracts.rwa.deployed}
          loading={contracts.rwa.loading}
        />
      </div>

      {!isLoading && !allDeployed && (
        <div style={{
          marginTop: '16px',
          padding: '12px',
          background: 'rgba(255, 170, 0, 0.1)',
          border: '1px solid rgba(255, 170, 0, 0.3)',
          borderRadius: '8px',
          color: '#ffaa00',
          fontSize: '0.875rem',
        }}>
          ⚠️ Some contracts are not deployed. Run <code>tilt up</code> to deploy the full stack.
        </div>
      )}
    </div>
  )
}

const ContractCard: React.FC<{
  name: string
  icon: React.ReactNode
  address: string
  deployed: boolean
  loading: boolean
}> = ({ name, icon, address, deployed, loading }) => {
  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      gap: '12px',
      padding: '12px',
      background: deployed ? 'rgba(0, 255, 136, 0.05)' : 'rgba(255, 255, 255, 0.03)',
      border: `1px solid ${deployed ? 'rgba(0, 255, 136, 0.2)' : 'rgba(255, 255, 255, 0.1)'}`,
      borderRadius: '8px',
    }}>
      {loading ? (
        <Loader2 className="animate-spin" size={20} color="#00bfff" />
      ) : deployed ? (
        <Check size={20} color="#00ff88" />
      ) : (
        <X size={20} color="#ff4444" />
      )}
      <span style={{ color: deployed ? '#00ff88' : 'rgba(255, 255, 255, 0.6)' }}>
        {icon}
      </span>
      <div style={{ flex: 1 }}>
        <div style={{ color: 'white', fontWeight: '600', fontSize: '0.9rem' }}>{name}</div>
        {address && (
          <div style={{ 
            color: 'rgba(255, 255, 255, 0.5)', 
            fontSize: '0.75rem',
            fontFamily: 'monospace',
          }}>
            {address.slice(0, 10)}...{address.slice(-8)}
          </div>
        )}
      </div>
      {deployed && (
        <a
          href={`http://localhost/address/${address}`}
          target="_blank"
          rel="noopener noreferrer"
          style={{
            padding: '4px 8px',
            background: 'rgba(0, 191, 255, 0.2)',
            border: '1px solid rgba(0, 191, 255, 0.4)',
            borderRadius: '6px',
            color: '#00bfff',
            fontSize: '0.75rem',
            textDecoration: 'none',
            fontWeight: '600',
          }}
        >
          View
        </a>
      )}
    </div>
  )
}

export default SystemStatus
