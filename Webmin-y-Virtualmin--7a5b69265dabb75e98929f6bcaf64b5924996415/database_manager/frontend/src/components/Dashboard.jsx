import React, { useState, useEffect } from 'react';
import DatabaseList from './DatabaseList';
import TableView from './TableView';

const Dashboard = () => {
    const [selectedConnection, setSelectedConnection] = useState(null);
    const [selectedDatabase, setSelectedDatabase] = useState(null);
    const [selectedTable, setSelectedTable] = useState(null);

    return (
        <div className="dashboard">
            <div className="sidebar">
                <DatabaseList 
                    onSelectConnection={setSelectedConnection}
                    onSelectDatabase={setSelectedDatabase}
                />
            </div>
            <div className="main-content">
                {selectedDatabase && selectedTable ? (
                    <TableView 
                        connection={selectedConnection}
                        database={selectedDatabase}
                        table={selectedTable}
                    />
                ) : (
                    <div className="welcome-message">
                        <h2>Database Manager</h2>
                        <p>Select a database and table to get started</p>
                    </div>
                )}
            </div>
        </div>
    );
};

export default Dashboard;
