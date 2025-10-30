import React from 'react';
import Dashboard from './components/Dashboard';
import QueryBuilder from './components/QueryBuilder';
import './App.css';

function App() {
  return (
    <div className="App">
      <header>
        <h1>Database Manager</h1>
      </header>
      <main>
        <Dashboard />
        <QueryBuilder />
      </main>
    </div>
  );
}

export default App;
