from pathlib import Path
import os
import sys
import psycopg2
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.exc import SQLAlchemyError

#Loading environment
load_dotenv()
DB_HOST=os.getenv("DB_HOST")
DB_PORT=os.getenv("DB_PORT")
DB_NAME=os.getenv("DB_NAME")
DB_USER=os.getenv("DB_USER")
DB_PASSWORD=os.getenv("DB_PASSWORD")

#Environment Error Handling
required_fields = {
    "DB_HOST": DB_HOST,
    "DB_PORT": DB_PORT,
    "DB_NAME": DB_NAME,
    "DB_USER": DB_USER,
    "DB_PASSWORD": DB_PASSWORD,
}
missing_fields = [field_name for field_name, value in required_fields.items() if not value]
if missing_fields:
    raise ValueError(
        f"Missing .env variables: {', '.join(missing)}"
    )

engine = create_engine(f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}")

#Directories
root_dir = Path(__file__).resolve().parent.parent
crm_dir = root_dir / "datasets" / "source_crm" 
erp_dir = root_dir / "datasets" / "source_erp"

#CSV Files
files = {
    "crm_cust_info": crm_dir / "cust_info.csv",
    "crm_prd_info": crm_dir / "prd_info.csv",
    "crm_sales_details": crm_dir / "sales_details.csv",
    "erp_cust_az12": erp_dir / "CUST_AZ12.csv",
    "erp_loc_a101": erp_dir / "LOC_A101.csv",
    "erp_px_cat_g1v2": erp_dir / "PX_CAT_G1V2.csv"
}

#Error During Loading List
file_error = []
empty_data_error = []
csv_error = []
database_error = []
unexpected_error = []

#Importing Data from CSV to PostgreSQL
for table_name, csv_path in files.items():
    try:
        if not csv_path.exists():
            raise FileNotFoundError(f"File not found: {csv_path}")
        
        df = pd.read_csv(csv_path)
        if df.empty:
            raise ValueError(f"{csv_path.name} contains no data.")

        df.columns = df.columns.str.lower()
        df.to_sql(
            name=table_name,
            schema="bronze",
            con=engine,
            if_exists="append",
            index=False,
            method="multi",
        )

        print(f"Loaded {csv_path.name} -> bronze.{table_name}")

    except FileNotFoundError as e:
        file_error.append(table_name)

    except pd.errors.EmptyDataError:
        empty_data_error.append(table_name)

    except pd.errors.ParserError as e:
        csv_error.append(table_name)

    except SQLAlchemyError as e:
        database_error.append(table_name)
        print(f"\nDATABASE ERROR while loading {csv_path.name}")
        print(f"Destination table: bronze.{table_name}")
        print(e)

    except Exception as e:
        unexpected_error.append(table_name)
    
print("File Errors: ", file_error)
print("Empty Data Errors: ", empty_data_error)
print("CSV Errors: ", csv_error)
print("Database Errors: ", database_error)
print("Exceptions: ", unexpected_error)