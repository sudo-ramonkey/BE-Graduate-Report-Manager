import Joi from 'joi';

class UsersValidator {
  createUser() {
    return Joi.object({
      user_name: Joi.string().max(100).trim().required(),
      password: Joi.string().min(8).max(255).trim().required(), 
      email: Joi.string().email().max(100).required(),
      role_id: Joi.number().required(),
      is_active: Joi.number().valid(0, 1).default(1),
      code: Joi.string().max(10).allow(null, ''),
    });
  }

  getUsers() {
    return Joi.object({}); 
  }

  updateUser() {
    return Joi.object({
      user_id: Joi.number().required(),
      user_name: Joi.string().max(100).trim().required(),
      email: Joi.string().email().max(100).required(),
      role_id: Joi.number().required(),
      is_active: Joi.number().valid(0, 1).default(1),
    });
  }

  deleteUser() {
    return Joi.object({
      user_id: Joi.number().required(),
    });
  }

  loginUser() {
    return Joi.object({
      user_name: Joi.string().required(),
      password: Joi.string().required(),
    });
  }

  requestPasswordReset() {
    return Joi.object({
      email: Joi.string().email().required(),
    });
  }

  resetPassword() {
    return Joi.object({
      email: Joi.string().email().required(),
      code: Joi.string().length(10).required(),
      newPassword: Joi.string().min(8).required(),
    });
  }

  refreshToken() {
    return Joi.object({
      refreshToken: Joi.string().required(),
    });
  }

  logout() {
    return Joi.object({
      refreshToken: Joi.string().required(),
    });
  }
}
export default new UsersValidator();