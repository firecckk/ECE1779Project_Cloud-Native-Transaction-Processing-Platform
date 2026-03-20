To test the database:

1. Deployment: 
    docker-compose up -d --build
    docker-compose up -d
    docker-compose down
    docker-compose ps

2. Connect to SQL:
    docker exec -it transaction-db psql -U user -d transaction_platform -c "\dt"
    



