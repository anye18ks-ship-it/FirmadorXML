import dotenv from 'dotenv';
import path from 'path';

// Cargar variables de entorno desde .env
dotenv.config();

export interface DatabaseConfig {
  server: string;
  port: number;
  user: string;
  password: string;
  database: string;
  options: {
    encrypt: boolean;
    trustServerCertificate: boolean;
    enableArithAbort: boolean;
  };
  pool: {
    max: number;
    min: number;
    idleTimeoutMillis: number;
    acquireTimeoutMillis: number;
  };
}

export interface AppConfig {
  database: DatabaseConfig;
  sap: {
    server: string;
    companyDb: string;
    user: string;
    password: string;
    licenseServer: string;
  };
  dgii: {
    env: 'test' | 'cert' | 'prod';
    testUrl: string;
    certUrl: string;
    prodUrl: string;
    activeBaseUrl: string;
  };
  server: {
    port: number;
    nodeEnv: string;
  };
}

const dgiiEnv = (process.env.DGII_ENV || 'test') as 'test' | 'cert' | 'prod';
const testUrl = process.env.DGII_TEST_URL || 'https://testecf.dgii.gov.do/testfe/';
const certUrl = process.env.DGII_CERT_URL || 'https://certifecf.dgii.gov.do/certecf/';
const prodUrl = process.env.DGII_PROD_URL || 'https://ecf.dgii.gov.do/fe/';

let activeBaseUrl = testUrl;
if (dgiiEnv === 'cert') activeBaseUrl = certUrl;
if (dgiiEnv === 'prod') activeBaseUrl = prodUrl;

export const config: AppConfig = {
  database: {
    server: process.env.DB_SERVER || '172.16.4.14',
    port: parseInt(process.env.DB_PORT || '1433', 10),
    user: process.env.DB_USER || 'sa',
    password: process.env.DB_PASSWORD || '@Gr0f3m',
    database: process.env.DB_NAME || 'cms',
    options: {
      encrypt: process.env.DB_ENCRYPT === 'true',
      trustServerCertificate: process.env.DB_TRUST_SERVER_CERTIFICATE !== 'false',
      enableArithAbort: true,
    },
    pool: {
      max: 15,
      min: 2,
      idleTimeoutMillis: 30000,
      acquireTimeoutMillis: 15000,
    },
  },
  sap: {
    server: process.env.SAP_SERVER || 'diamante',
    companyDb: process.env.SAP_COMPANY_DB || 'SBO_AGROFEM',
    user: process.env.SAP_USER || 'manager',
    password: process.env.SAP_PASSWORD || 'a2509',
    licenseServer: process.env.SAP_LICENSE_SERVER || 'diamante:30000',
  },
  dgii: {
    env: dgiiEnv,
    testUrl,
    certUrl,
    prodUrl,
    activeBaseUrl,
  },
  server: {
    port: parseInt(process.env.PORT || '5000', 10),
    nodeEnv: process.env.NODE_ENV || 'development',
  },
};
