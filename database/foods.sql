CREATE DATABASE foods;

CREATE TABLE foods (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price INTEGER NOT NULL
);

INSERT INTO foods (name, price) VALUES 
('Hamburger', 20000);