import express from 'express';
import helmet from 'helmet';
import cors from 'cors';

const PORT = process.env.API_PORT || 3000;


const app = express();

//Configuraciones de seguridad y middlewares
app.use(helmet());
app.use(express.json());
app.use(cors());
app.use(express.urlencoded({extended: true}));


app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});