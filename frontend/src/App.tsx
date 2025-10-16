/*import { useState } from 'react'
import reactLogo from './assets/react.svg'
import viteLogo from '/vite.svg'
import './App.css'

function App() {
  const [count, setCount] = useState(0)

  return (
    <>
      <div>
        <a href="https://vite.dev" target="_blank">
          <img src={viteLogo} className="logo" alt="Vite logo" />
        </a>
        <a href="https://react.dev" target="_blank">
          <img src={reactLogo} className="logo react" alt="React logo" />
        </a>
      </div>
      <h1>Vite + React</h1>
      <div className="card">
        <button onClick={() => setCount((count) => count + 1)}>
          count is {count}
        </button>
        <p>
          Edit <code>src/App.tsx</code> and save to test HMR
        </p>
      </div>
      <p className="read-the-docs">
        Click on the Vite and React logos to learn more
      </p>
    </>
  )
}

export default App*/

import RWAInterface from './components/RWAInterface'
import SystemStatus from './components/SystemStatus'
import { Toaster } from 'react-hot-toast'
import './App.css'

function App() {
  return (
    <div className="app">
      <div style={{ 
        maxWidth: '1200px', 
        margin: '0 auto', 
        padding: '40px 20px' 
      }}>
        <div style={{ 
          textAlign: 'center', 
          marginBottom: '40px' 
        }}>
          <h1 style={{ 
            fontSize: '3rem', 
            margin: '0 0 12px 0',
            background: 'linear-gradient(135deg, #00bfff 0%, #0080ff 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
          }}>
            Evolve RWA Demo
          </h1>
          <p style={{ 
            color: 'rgba(255, 255, 255, 0.7)',
            fontSize: '1.1rem',
            margin: 0,
          }}>
            Real-World Asset Tokenization on Sovereign Rollup
          </p>
        </div>

        <SystemStatus rpcUrl="http://localhost:8545" />
        <RWAInterface />
      </div>
      
      <Toaster
        position="bottom-right"
        toastOptions={{
          style: {
            background: 'rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(10px)',
            border: '1px solid rgba(255, 255, 255, 0.2)',
            color: 'white',
          },
        }}
      />
    </div>
  )
}

export default App
