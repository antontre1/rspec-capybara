# à lancer avec : rails new my_project -T -d postgresql --css=sass --javascript=webpack -m ../app-templates/rspec-capybara.rb
gem_group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'capybara'
  gem 'webdrivers'
  gem 'faker'
  gem 'selenium-devtools', '= 0.124.0'
end
initializer 'generators.rb', <<-CODE
  Rails.application.config.generators do |g|
    g.test_framework :rspec,
      fixtures: false,
      view_specs: false,
      helper_specs: false,
      routing_specs: false,
      request_specs: false,
      controller_specs: false
  end

CODE

run "bundle lock --add-platform aarch64-linux"

# Exécuter des commandes après que les gemmes soient installées
after_bundle do
  # Installer RSpec
  generate 'rspec:install'

  # Générer le scaffold pour les Posts
  generate 'scaffold', 'Post title:string body:text'
  # Générer le scaffold pour les Comments
  generate 'scaffold', 'Comment post:references content:text'

  # Migrer la base de données après la génération des scaffolds
  rails_command 'db:migrate'

  # Ajouter des relations dans les modèles
  inject_into_file 'app/models/post.rb', after: "class Post < ApplicationRecord\n" do
    <<-RUBY
      has_many :comments, dependent: :destroy
    RUBY
  end

  inject_into_file 'app/models/comment.rb', after: "class Comment < ApplicationRecord\n" do
    <<-RUBY
      belongs_to :post
    RUBY
  end

  # Préparer le Gemfile.lock pour une compatibilité multi-plateforme, utile pour Docker
  run "bundle lock --add-platform x86_64-linux --add-platform x86_64-darwin-20 --add-platform aarch64-linux --add-platform x64-mingw32 --add-platform x86-mingw32"
  # Installer les gems après l'ajout des plateformes
  run "bundle install"

remove_file 'spec/models/post_spec.rb'
create_file 'spec/models/post_spec.rb', <<-RUBY
require 'rails_helper'

RSpec.describe Post, type: :model do
  # Test pour la création d'un post
  describe 'creation' do
    it 'creates a post successfully with valid attributes' do
      post = create(:post)
      expect(post).to be_persisted
      expect(post.title).to eq("MyString")
      expect(post.body).to eq("MyText")
    end
  end

  # Test pour la lecture d'un post
  describe 'reading' do
    let!(:post) { create(:post) }

    it 'finds a post by id' do
      expect(Post.find(post.id)).to eq(post)
    end
  end

  # Test pour la mise à jour d'un post
  describe 'updating' do
    let!(:post) { create(:post) }

    it 'updates a post with new attributes' do
      post.update(title: "New title", body: "New body")
      post.reload # Recharger l'objet à partir de la base de données
      expect(post.title).to eq("New title")
      expect(post.body).to eq("New body")
    end
  end

  # Test pour la suppression d'un post
  describe 'deleting' do
    let!(:post) { create(:post) }

    it 'deletes a post' do
      expect { post.destroy }.to change(Post, :count).by(-1)
    end
  end
end
RUBY


# Ajouter "require 'capybara/rspec'" avant "RSpec.configure do |config|" dans spec/spec_helper.rb
inject_into_file 'spec/spec_helper.rb', before: "RSpec.configure do |config|\n" do
  "require 'capybara/rspec'\n"
end

# Ajouter la configuration de Capybara dans les tests système à spec/spec_helper.rb
inject_into_file 'spec/spec_helper.rb', after: "RSpec.configure do |config|\n" do
  <<-RUBY.indent(2)
  config.before(:each, type: :system) do
    driven_by Capybara.javascript_driver
  end
  RUBY
end

# Ajouter le chargement des fichiers de support au début de spec/rails_helper.rb
inject_into_file 'spec/rails_helper.rb', after: "require 'rspec/rails'\n" do
<<-RUBY
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }
RUBY
end

inject_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
  <<-RUBY.indent(2)
  config.include FactoryBot::Syntax::Methods
  RUBY
end

run "mkdir -p spec/system"

create_file 'spec/system/mon_test.rb', <<-RUBY
require 'spec_helper'
require 'selenium-webdriver'
require 'rails_helper'


RSpec.describe 'Using Selenium' do

  it 'go to posts' do
   visit posts_path
   save_screenshot('postspage.png')
  end
end

RUBY

run "mkdir -p spec/support"

# Créer ou remplacer le fichier spec/support/capybara.rb avec le contenu spécifié
create_file 'spec/support/capybara.rb', <<-RUBY
require 'selenium/webdriver'
Capybara.server_host = 'web'
selenium_host = 'selenium'
Capybara.server_port = 3000
Capybara.run_server = false
Capybara.app_host = "http://\#{Capybara.server_host}:\#{Capybara.server_port}"

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument '--window-size=1680,1050'

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://\#{selenium_host}:4444/wd/hub",
    options: options
  )
end

Capybara.register_driver :selenium_mobile do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_emulation(device_name: 'iPhone X')

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://\#{selenium_host}:4444/wd/hub",
    options: options
  )
end

Capybara.javascript_driver = :selenium_mobile
Capybara.default_driver = :selenium_mobile
RUBY

create_file '.env', <<-ENV
DB_USERNAME=postgres
DB_PASSWORD=diogene
LAUNCHY_DRY_RUN=true
BROWSER=/dev/null
ENV

remove_file 'config/routes.rb'
create_file 'config/routes.rb', <<-RUBY
Rails.application.routes.draw do
  root to: 'posts#index'
  resources :posts do
      resources :comments
    end
end
RUBY

  # Ajouter des relations dans les modèles
    inject_into_file 'app/models/post.rb', after: "class Post < ApplicationRecord\n" do
    <<-RUBY
    has_many :comments, dependent: :destroy
    RUBY
  end

    inject_into_file 'app/models/comment.rb', after: "class Comment < ApplicationRecord\n" do
    <<-RUBY
    belongs_to :post
    RUBY
  end

  inject_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
  "  config.include FactoryBot::Syntax::Methods\n"
end


    remove_file 'config/database.yml'
    create_file 'config/database.yml', <<-YML
  default: &default
    adapter: postgresql
    encoding: unicode
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

  development:
    <<: *default
    database: <%= ENV["DB_DATABASE"] %>
    port: <%= ENV["DB_PORT"] %>
    username: <%= ENV['DB_USERNAME'] %>
    password: <%= ENV['DB_PASSWORD'] %>
    host: <%= ENV['DB_HOST'] %>

  test:
    <<: *default
    database: <%= ENV["DB_DATABASE"] %>
    port: <%= ENV["DB_PORT"] %>
    username: <%= ENV['DB_USERNAME'] %>
    password: <%= ENV['DB_PASSWORD'] %>
    host: <%= ENV['DB_HOST'] %>

  production:
    <<: *default
    database: <%= ENV["DB_DATABASE"] %>
    port: <%= ENV["DB_PORT"] %>
    username: <%= ENV['DB_USERNAME'] %>
    password: <%= ENV['DB_PASSWORD'] %>
    host: <%= ENV['DB_HOST'] %>
  YML

    create_file 'lib/tasks/db_exists.rake', <<-TASK
  namespace :db do
    desc 'Check if database connection exists'
    task :exists do
      Rake::Task['environment'].invoke
      ActiveRecord::Base.connection
    rescue StandardError
      puts 'Database connection failed'
      exit 1
    else
      puts 'Database connection successful'
      exit 0
    end
    desc 'Load seed data for development'
    task seed_dev: :environment do
      # Load the users and products seed files
      load "./db/seeds.dev.rb"
    end
  end
  TASK

    remove_file 'Dockerfile'
    create_file 'Dockerfile', <<-DOCKER
  FROM ruby:3.2.2
  RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y build-essential nodejs postgresql-client yarn tini libvips42 libvips-dev  mupdf mupdf-tools zsh git && \
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="af-magic"/g' ~/.zshrc \
    chsh -s $(which zsh) \
    apt-get clean && rm -rf /var/lib/apt/lists/*
  RUN mkdir /app-setup
  WORKDIR /app
  COPY ./Gemfile* ./package.json ./yarn.lock ./
  RUN yarn install && \
      bundle install
  WORKDIR /app-setup
  COPY bin/docker-entrypoint .
  RUN chown root:root docker-entrypoint && \
  chmod +x docker-entrypoint
  WORKDIR /app
  EXPOSE 3000
  CMD ["bash"]

  ENTRYPOINT [ "../app-setup/docker-entrypoint" ]
  DOCKER

  # Créer le fichier docker-compose.yml
    create_file 'docker-compose.yml', <<~YAML
  version: '3'
  services:
    db:
      image: postgres:14-alpine
      restart: always
      environment:
        - POSTGRES_USER=postgres
        - POSTGRES_PASSWORD=PASSWORD
      ports:
        - '5455:5432'
      volumes:
        - ./postgres-data/test/db:/var/lib/postgresql/data
      expose:
        - '5432'
    web:
      tty: true
      stdin_open: true
      build:
        context: .
        dockerfile: Dockerfile
      volumes:
        - .:/app
      depends_on:
        - db
        - redis
      ports:
        - '3000:3000'
      env_file:
        - .env
      environment:
        DB_USERNAME: "postgres"
        DB_PASSWORD: "PASSWORD"
        DB_DATABASE: "my_app_test"
        DB_PORT: 5432
        DB_HOST: db
        REDIS_URL: redis://redis:6379/0
        RAILS_ENV: test
        RAILS_MAX_THREADS: 5
        APP_DOMAIN_NAME: localhost

    redis:
      image: 'redis:latest'
      command: redis-server
      volumes:
        - './redis_data:/data'
      ports:
        - '6379:6379'

    selenium:
      image: seleniarm/standalone-chromium:102.0.5005.61
      environment:
        START_XVFB: 'true'
        SE_NODE_MAX_SESSIONS: 5
        JAVA_OPTS: "-XX:ActiveProcessorCount=5"
        SE_NODE_OVERRIDE_MAX_SESSIONS: 5
        SE_VNC_PASSWORD: 'password'
      volumes:
        - /dev/shm:/dev/shm # Aide à éviter certains problèmes liés au navigateur
      ports:
        - "4444:4444"
        - "5991:5900"
  YAML

remove_file 'bin/docker-entrypoint'
create_file 'bin/docker-entrypoint', <<-SCRIPT
#!/bin/bash -e
echo "pwd"
echo \$PWD
until pg_isready -h \${DB_HOST} -p \${DB_PORT} -U \${DB_USERNAME} > /dev/null 2>&1
do
  echo "Waiting for database to become ready on \${DB_HOST}:\${DB_PORT} with user \${DB_USERNAME}..."
  sleep 1
done
echo "Database is ready!"

# Se déplacer dans le répertoire du projet Rails
cd /app

# Configuration de la base de données
if rails db:exists
then
  echo "Database already exists, skipping db:drop and db:create"
  rails db:migrate
else
  echo "Database does not exist, running db:drop and db:create"
  rails db:drop
  rails db:create
  rails db:migrate
  echo "Database created"
  # echo "Running db:seed_dev"
  # rails db:seed_dev
fi
echo "Database is set up"

# Installation des dépendances
echo "Installing dependencies..."
bundle install
yarn install

# Préparation de l'environnement de test
echo "Preparing test environment..."
bundle exec rake db:test:prepare
rm -f tmp/pids/server.pid
exec rails s -p 3000 -b '0.0.0.0' -e \${RAILS_ENV} &

# Lancement des tests : mettre le code de lancement adapté ici
echo "Running tests..."
bundle exec rspec ./spec/models
echo "Tests completed! Entering idle mode to keep the container alive..."

while true; do
  sleep 3600
done
SCRIPT

# Ajouter des règles supplémentaires au fichier .gitignore
append_to_file '.gitignore', <<-GITIGNORE

# Ignore .DS_Store file (https://dev.to/vonhyou/remove-dsstore-file-from-git-repo-2g57)
.DS_Store
**/.DS_Store
/postgres-data/

# Ignore application configuration
/config/application.yml

# Ignore byebug history
.byebug_history
!/app/assets/builds/.keep
version.txt

# Ignore redis binary dump (dump.rdb) files
*.rdb
GITIGNORE


end
