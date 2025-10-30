import React, { useState, useEffect } from 'react';

const TableView = ({ connection, database, table }) => {
    const [tableData, setTableData] = useState([]);
    const [columns, setColumns] = useState([]);
    const [editingRow, setEditingRow] = useState(null);
    const [newRow, setNewRow] = useState({});

    // Fetch table data
    useEffect(() => {
        fetchTableData();
    }, [connection, database, table]);

    const fetchTableData = () => {
        fetch(`/api/${connection.id}/${database.name}/${table.name}`)
            .then(response => response.json())
            .then(data => {
                setTableData(data.rows);
                setColumns(data.columns);
            });
    };

    const handleEdit = (rowIndex) => {
        setEditingRow(rowIndex);
    };

    const handleSave = (rowIndex) => {
        const rowData = tableData[rowIndex];
        // Send update to backend
        fetch(`/api/${connection.id}/${database.name}/${table.name}/update`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                primaryKey: rowData[columns[0].name],  // Assuming first column is primary key
                updates: rowData
            })
        })
        .then(response => response.json())
        .then(result => {
            if (result.success) {
                setEditingRow(null);
                fetchTableData();  // Refresh data
            }
        });
    };

    const handleDelete = (rowIndex) => {
        const rowData = tableData[rowIndex];
        if (window.confirm('Are you sure you want to delete this record?')) {
            fetch(`/api/${connection.id}/${database.name}/${table.name}/delete`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    primaryKey: rowData[columns[0].name]
                })
            })
            .then(response => response.json())
            .then(result => {
                if (result.success) {
                    fetchTableData();  // Refresh data
                }
            });
        }
    };

    const handleAddNew = () => {
        fetch(`/api/${connection.id}/${database.name}/${table.name}/insert`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(newRow)
        })
        .then(response => response.json())
        .then(result => {
            if (result.success) {
                setNewRow({});
                fetchTableData();  // Refresh data
            }
        });
    };

    return (
        <div className="table-view">
            <h2>{table.name}</h2>
            
            {/* New record form */}
            <div className="new-record">
                <h3>Add New Record</h3>
                {columns.map(col => (
                    <input
                        key={col.name}
                        type="text"
                        placeholder={col.name}
                        value={newRow[col.name] || ''}
                        onChange={(e) => setNewRow({...newRow, [col.name]: e.target.value})}
                    />
                ))}
                <button onClick={handleAddNew}>Add</button>
            </div>
            
            {/* Data table */}
            <table>
                <thead>
                    <tr>
                        {columns.map(col => (
                            <th key={col.name}>{col.name}</th>
                        ))}
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    {tableData.map((row, index) => (
                        <tr key={index}>
                            {columns.map(col => (
                                <td key={col.name}>
                                    {editingRow === index ? (
                                        <input
                                            type="text"
                                            value={row[col.name]}
                                            onChange={(e) => {
                                                const updatedData = [...tableData];
                                                updatedData[index][col.name] = e.target.value;
                                                setTableData(updatedData);
                                            }}
                                        />
                                    ) : (
                                        row[col.name]
                                    )}
                                </td>
                            ))}
                            <td>
                                {editingRow === index ? (
                                    <button onClick={() => handleSave(index)}>Save</button>
                                ) : (
                                    <>
                                        <button onClick={() => handleEdit(index)}>Edit</button>
                                        <button onClick={() => handleDelete(index)}>Delete</button>
                                    </>
                                )}
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
};

export default TableView;
