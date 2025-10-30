import React, { useState } from 'react';

const QueryBuilder = ({ connection, database }) => {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [error, setError] = useState('');

    const executeQuery = () => {
        fetch(`/api/${connection.id}/${database.name}/query`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query })
        })
        .then(response => response.json())
        .then(data => {
            if (data.error) {
                setError(data.error);
                setResults([]);
            } else {
                setResults(data.results);
                setError('');
            }
        })
        .catch(err => {
            setError('Failed to execute query');
            setResults([]);
        });
    };

    return (
        <div className="query-builder">
            <h3>Query Builder</h3>
            <textarea 
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Enter SQL query"
            />
            <button onClick={executeQuery}>Execute</button>
            
            {error && <div className="error">{error}</div>}
            
            {results.length > 0 && (
                <table>
                    <thead>
                        <tr>
                            {Object.keys(results[0]).map(key => (
                                <th key={key}>{key}</th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {results.map((row, index) => (
                            <tr key={index}>
                                {Object.values(row).map((value, idx) => (
                                    <td key={idx}>{value}</td>
                                ))}
                            </tr>
                        ))}
                    </tbody>
                </table>
            )}
        </div>
    );
};

export default QueryBuilder;
