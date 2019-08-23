require './config/environment'

use Torb::ActionsController
use Torb::AdminController
use Torb::EventsController
use Torb::UsersController

run Torb::ApplicationController
