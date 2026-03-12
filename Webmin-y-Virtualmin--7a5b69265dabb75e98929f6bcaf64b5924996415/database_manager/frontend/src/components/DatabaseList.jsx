import React, { useState, useEffect } from 'react';

const DatabaseList = ({ onSelectConnection, onSelectDatabase }) => {
    const [connections, setConnections] = useState([]);
    const [databases, setDatabases] = useState([]);

    useEffect(() => {
        // Fetch saved connections
        fetch('/api/connections')
            .then(response => response.json())
            .then(data => setConnections(data));
    }, []);

    const handleConnectionSelect = (connection) => {
        onSelectConnection(connection);
        // Fetch databases for the selected connection
        fetch(`/api/${connection.id}/databases`)
            .then(response => response.json())
            .then(data => setDatabases(data));
    };

    return (
        <div className="database-list">
            <h3>Connections</h3>
            <ul>
                {connections.map(conn => (
                    <li key={conn.id} onClick={() => handleConnectionSelect(conn)}>
                        {conn.name} ({conn.db_type})
                    </li>
                ))}
            </ul>

            <h3>Databases</h3>
            <ul>
                {databases.map(db => (
                    <li key={db.name} onClick={() => onSelectDatabase(db)}>
                        {db.name}
                    </li>
                ))}
            </ul>
        </div>
    );
};

export default DatabaseList;
