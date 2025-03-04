# main.py
import os
import click
import uvicorn

from core import config

@click.command()
@click.option("--env", type=click.Choice(["local", "dev", "prod"], case_sensitive=False), default="local")
@click.option("--debug", is_flag=True, default=False)
def main(env: str, debug: bool):
    os.environ["ENV"] = env
    os.environ["DEBUG"] = str(debug)
    
    # Host i port pobierzemy z configu (zależnego od env)
    uvicorn.run(
        app="app.server:app",
        host=config.APP_HOST,
        port=config.APP_PORT,
        reload=(env != "prod"),  # Tylko w lokal/dev
        workers=4,
    )

if __name__ == "__main__":
    main()
